use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TaskStatus {
    Pending,
    Processing,
    Completed,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConversionTask {
    pub id: String,
    pub input_path: String,
    pub output_path: String,
    pub output_format: String,
    pub status: TaskStatus,
    pub progress: f32,
    pub error_message: Option<String>,
}

type TaskHandle = Arc<RwLock<ConversionTask>>;

pub struct TaskManager {
    tasks: RwLock<Vec<TaskHandle>>,
}

impl TaskManager {
    pub fn new() -> Self {
        Self {
            tasks: RwLock::new(Vec::new()),
        }
    }

    pub async fn add_task(&self, task: ConversionTask) -> TaskHandle {
        let task_arc = Arc::new(RwLock::new(task));
        self.tasks.write().await.push(task_arc.clone());
        task_arc
    }

    pub async fn get_task(&self, id: &str) -> Option<TaskHandle> {
        let tasks = self.tasks.read().await;
        tasks.iter().find(|t| {
            let rt = t.try_read();
            rt.map(|task| task.id == id).unwrap_or(false)
        }).cloned()
    }

    pub async fn list_tasks(&self) -> Vec<TaskHandle> {
        self.tasks.read().await.clone()
    }

    pub async fn update_progress(&self, id: &str, progress: f32) {
        if let Some(task) = self.get_task(id).await {
            let mut t = task.write().await;
            t.progress = progress;
        }
    }

    pub async fn update_status(&self, id: &str, status: TaskStatus) {
        if let Some(task) = self.get_task(id).await {
            let mut t = task.write().await;
            t.status = status;
        }
    }

    pub async fn set_completed(&self, id: &str, output_path: String) {
        if let Some(task) = self.get_task(id).await {
            let mut t = task.write().await;
            t.status = TaskStatus::Completed;
            t.progress = 100.0;
            t.output_path = output_path;
        }
    }

    pub async fn set_failed(&self, id: &str, error: String) {
        if let Some(task) = self.get_task(id).await {
            let mut t = task.write().await;
            t.status = TaskStatus::Failed;
            t.error_message = Some(error);
        }
    }

    pub async fn remove_task(&self, id: &str) -> bool {
        let mut tasks = self.tasks.write().await;
        let len_before = tasks.len();
        tasks.retain(|t| {
            let rt = t.try_read();
            rt.map(|task| task.id != id).unwrap_or(true)
        });
        tasks.len() < len_before
    }
}

impl Default for TaskManager {
    fn default() -> Self {
        Self::new()
    }
}
