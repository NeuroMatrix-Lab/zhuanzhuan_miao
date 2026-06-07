use thiserror::Error;

#[derive(Error, Debug)]
pub enum FfmpegError {
    #[error("FFmpeg not found")]
    NotFound,
    
    #[error("Invalid input file: {0}")]
    InvalidInput(String),
    
    #[error("Invalid output format: {0}")]
    InvalidOutputFormat(String),
    
    #[error("Conversion failed: {0}")]
    ConversionFailed(String),
    
    #[error("Task not found: {0}")]
    TaskNotFound(String),
    
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("FFmpeg execution error: {0}")]
    FfmpegError(String),
}

impl serde::Serialize for FfmpegError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.to_string())
    }
}
