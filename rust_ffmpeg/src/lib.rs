mod error;
mod ffmpeg;
mod task;

pub use error::FfmpegError;
pub use task::{ConversionTask, TaskStatus, TaskManager};
pub use ffmpeg::FfmpegConverter;

use std::sync::Arc;

// 全局实例
static TASK_MANAGER: std::sync::OnceLock<Arc<TaskManager>> = std::sync::OnceLock::new();

fn get_task_manager() -> Arc<TaskManager> {
    TASK_MANAGER.get_or_init(|| Arc::new(TaskManager::new())).clone()
}

/// 初始化日志
pub fn init_logger() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
}

/// 获取 FFmpeg 转换器实例
pub fn get_converter() -> FfmpegConverter {
    FfmpegConverter::new(get_task_manager())
}

#[flutter_rust_bridge::frb(sync)]
pub fn convert(
    input_path: String,
    output_path: String,
    output_format: String,
) -> Result<String, String> {
    convert_blocking(input_path, output_path, output_format)
}

fn convert_blocking(
    input_path: String,
    output_path: String,
    output_format: String,
) -> Result<String, String> {
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
    rt.block_on(async {
        let converter = get_converter();
        converter
            .convert(&input_path, &output_path, &output_format)
            .await
            .map_err(|e| e.to_string())
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_task(task_id: String) -> Option<ConversionTask> {
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string()).unwrap();
    rt.block_on(async {
        let converter = get_converter();
        converter.get_task(&task_id).await
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_tasks() -> Vec<ConversionTask> {
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string()).unwrap();
    rt.block_on(async {
        let converter = get_converter();
        converter.list_tasks().await
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn cancel_task(task_id: String) -> Result<(), String> {
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string()).unwrap();
    rt.block_on(async {
        let converter = get_converter();
        converter.cancel_task(&task_id).await.map_err(|e| e.to_string())
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_supported_formats() -> Vec<FormatInfo> {
    vec![
        FormatInfo { format: "mp4".to_string(), name: "MP4 Video".to_string(), is_video: true },
        FormatInfo { format: "avi".to_string(), name: "AVI Video".to_string(), is_video: true },
        FormatInfo { format: "mkv".to_string(), name: "MKV Video".to_string(), is_video: true },
        FormatInfo { format: "webm".to_string(), name: "WebM Video".to_string(), is_video: true },
        FormatInfo { format: "mov".to_string(), name: "MOV Video".to_string(), is_video: true },
        FormatInfo { format: "mp3".to_string(), name: "MP3 Audio".to_string(), is_video: false },
        FormatInfo { format: "wav".to_string(), name: "WAV Audio".to_string(), is_video: false },
        FormatInfo { format: "aac".to_string(), name: "AAC Audio".to_string(), is_video: false },
        FormatInfo { format: "flac".to_string(), name: "FLAC Audio".to_string(), is_video: false },
        FormatInfo { format: "ogg".to_string(), name: "OGG Audio".to_string(), is_video: false },
        FormatInfo { format: "gif".to_string(), name: "GIF Animation".to_string(), is_video: true },
        FormatInfo { format: "jpg".to_string(), name: "JPEG Image".to_string(), is_video: true },
        FormatInfo { format: "png".to_string(), name: "PNG Image".to_string(), is_video: true },
    ]
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct FormatInfo {
    pub format: String,
    pub name: String,
    pub is_video: bool,
}

// Schema 声明必须放在最后
flutter_rust_bridge::frb_generated_placeholder!();
