use std::path::Path;
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;

use crate::error::FfmpegError;
use crate::task::{ConversionTask, TaskManager, TaskStatus};

pub struct FfmpegConverter {
    task_manager: std::sync::Arc<TaskManager>,
}

impl FfmpegConverter {
    pub fn new(task_manager: std::sync::Arc<TaskManager>) -> Self {
        Self { task_manager }
    }

    pub async fn convert(
        &self,
        input_path: &str,
        output_path: &str,
        output_format: &str,
    ) -> Result<String, FfmpegError> {
        // 检查输入文件
        if !Path::new(input_path).exists() {
            return Err(FfmpegError::InvalidInput(input_path.to_string()));
        }

        // 生成任务 ID
        let task_id = uuid::Uuid::new_v4().to_string();

        // 创建任务
        let task = ConversionTask {
            id: task_id.clone(),
            input_path: input_path.to_string(),
            output_path: output_path.to_string(),
            output_format: output_format.to_string(),
            status: TaskStatus::Pending,
            progress: 0.0,
            error_message: None,
        };

        let _task_arc = self.task_manager.add_task(task).await;
        
        // 更新状态为处理中
        self.task_manager.update_status(&task_id, TaskStatus::Processing).await;

        // 执行转换
        let result = self.execute_ffmpeg(&task_id, input_path, output_path, output_format).await;

        match result {
            Ok(_) => {
                self.task_manager.set_completed(&task_id, output_path.to_string()).await;
                Ok(task_id)
            }
            Err(e) => {
                self.task_manager.set_failed(&task_id, e.to_string()).await;
                Err(e)
            }
        }
    }

    async fn execute_ffmpeg(
        &self,
        task_id: &str,
        input_path: &str,
        output_path: &str,
        output_format: &str,
    ) -> Result<(), FfmpegError> {
        // 构建 FFmpeg 命令
        let mut cmd = Command::new("ffmpeg");
        cmd.args([
            "-i", input_path,
            "-y", // 覆盖输出文件
            "-progress", "pipe:1", // 输出进度到 stdout
            "-nostats",
        ]);

        // 根据输出格式添加编码参数
        match output_format.to_lowercase().as_str() {
            "mp4" => {
                cmd.args(["-c:v", "libx264", "-preset", "medium", "-crf", "23"]);
                cmd.args(["-c:a", "aac", "-b:a", "128k"]);
            }
            "avi" => {
                cmd.args(["-c:v", "libxvid", "-b:v", "2000k"]);
                cmd.args(["-c:a", "libmp3lame", "-b:a", "192k"]);
            }
            "mkv" => {
                cmd.args(["-c:v", "libx264", "-preset", "medium"]);
                cmd.args(["-c:a", "aac"]);
            }
            "mp3" => {
                cmd.arg("-vn"); // 无视频
                cmd.args(["-c:a", "libmp3lame", "-b:a", "192k"]);
            }
            "wav" => {
                cmd.arg("-vn");
                cmd.args(["-c:a", "pcm_s16le"]);
            }
            "aac" => {
                cmd.arg("-vn");
                cmd.args(["-c:a", "aac", "-b:a", "128k"]);
            }
            "webm" => {
                cmd.args(["-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0"]);
                cmd.args(["-c:a", "libopus", "-b:a", "128k"]);
            }
            "gif" => {
                cmd.args(["-vf", "fps=15,scale=480:-1", "-loop", "0"]);
            }
            "jpg" | "jpeg" | "png" => {
                cmd.args(["-frames:v", "1", "-q:v", "2"]);
            }
            _ => {
                // 默认直接复制流
                cmd.args(["-c", "copy"]);
            }
        }

        cmd.arg(output_path);

        log::info!("Executing FFmpeg: {:?}", cmd);

        let mut child = cmd
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| FfmpegError::FfmpegError(e.to_string()))?;

        let stdout = child.stdout.take().ok_or_else(|| FfmpegError::FfmpegError("Failed to capture stdout".to_string()))?;
        
        let task_manager = self.task_manager.clone();
        let task_id_owned = task_id.to_string();
        
        // 异步解析进度
        tokio::spawn(async move {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();
            
            while let Ok(Some(line)) = lines.next_line().await {
                if line.starts_with("out_time_ms=") {
                    if let Some(time_ms) = line.strip_prefix("out_time_ms=") {
                        if let Ok(ms) = time_ms.parse::<f64>() {
                            // 估算进度（需要总时长，这里简化处理）
                            let progress = (ms / 1000.0 / 30.0).min(99.0) as f32; // 假设最大30秒
                            task_manager.update_progress(&task_id_owned, progress).await;
                        }
                    }
                }
            }
        });

        let status = child.wait().await
            .map_err(|e| FfmpegError::FfmpegError(e.to_string()))?;

        if status.success() {
            Ok(())
        } else {
            Err(FfmpegError::ConversionFailed(format!("FFmpeg exited with: {}", status)))
        }
    }

    pub async fn get_task(&self, task_id: &str) -> Option<ConversionTask> {
        let task_arc = self.task_manager.get_task(task_id).await?;
        let task = task_arc.read().await;
        Some(task.clone())
    }

    pub async fn list_tasks(&self) -> Vec<ConversionTask> {
        let tasks = self.task_manager.list_tasks().await;
        let mut result = Vec::new();
        for task_arc in tasks {
            let task = task_arc.read().await;
            result.push(task.clone());
        }
        result
    }

    pub async fn cancel_task(&self, task_id: &str) -> Result<(), FfmpegError> {
        let task = self.task_manager.get_task(task_id).await
            .ok_or_else(|| FfmpegError::TaskNotFound(task_id.to_string()))?;
        
        {
            let mut t = task.write().await;
            if t.status == TaskStatus::Completed || t.status == TaskStatus::Failed {
                return Err(FfmpegError::ConversionFailed("Task already finished".to_string()));
            }
            t.status = TaskStatus::Cancelled;
        }
        
        self.task_manager.remove_task(task_id).await;
        Ok(())
    }
}
