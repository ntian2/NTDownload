//
//  NTDownloadManager.swift
//
//  Created by ntian on 2017/5/1.
//  Copyright © 2017年 ntian. All rights reserved.
//

import UIKit

open class NTDownloadManager: URLSessionDownloadTask {
    
    /// 单例
    open static let shared = NTDownloadManager()
    open var configuration = URLSessionConfiguration.background(withIdentifier: "NTDownload")
    /// 下载管理器代理
    open weak var downloadManagerDelegate: NTDownloadManagerDelegate?
    /// 任务列表
    private lazy var taskList = [NTDownloadTask]()
    private var session: URLSession!
    /// Plist存储路径
    private let plistPath = "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/NTDownload.plist"
    /// 文件存储路径
    private let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    //
    private let taskDescriptionFileURL = 0
    private let taskDescriptionFileName = 1
    private let taskDescriptionFileImage = 2
    
    override init() {
        super.init()
        
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        self.loadTaskList()
        debugPrint(plistPath)
        initDownloadTasks()
    }
    /// 未完成列表
    open var unFinishedList: [NTDownloadTask] {
        return taskList.filter({ (task) -> Bool in
            return task.status != .NTFinishedDownload
        })
    }
    /// 完成列表
    open var finishedList: [NTDownloadTask] {
        return taskList.filter({ (task) -> Bool in
            return task.status == .NTFinishedDownload
        })
    }
    /// 添加下载文件任务
    public func addDownloadTask(urlString: String, fileName: String? = nil, fileImage: String? = nil) {
        guard let url = URL(string: urlString) else {
            return
        }
        if url.scheme != "http" && url.scheme != "https" {
            return
        }
        for task in taskList {
            if task.fileURL == url {
                return
            }
        }
        let request = URLRequest(url: url)
        let downloadTask = session.downloadTask(with: request)
        downloadTask.resume()
        let status = NTDownloadStatus(rawValue: downloadTask.state.rawValue)!
        let fileName = fileName ?? (url.absoluteString as NSString).lastPathComponent
        let task = NTDownloadTask(fileURL: url, fileName: fileName, taskIdentifier: downloadTask.taskIdentifier, fileImage: fileImage, status: status)
        downloadTask.taskDescription = [urlString, fileName, fileImage ?? ""].joined(separator: ",")
        task.task = downloadTask
        self.taskList.append(task)
        downloadManagerDelegate?.addedDownload?(task: task)
//        self.saveTaskList()
        print(taskList[0])
    }
    /// 暂停下载文件
    public func pauseTask(fileInfo: NTDownloadTask) {
        if fileInfo.status == .NTFinishedDownload || fileInfo.status != .NTDownloading {
            return
        }
        let downloadTask = fileInfo.task!
        downloadTask.suspend()
        fileInfo.status = .NTStopDownload
        fileInfo.delegate?.downloadTaskStopDownload?(task: fileInfo)
        print(taskList[0])
    }
    /// 恢复下载文件
    public func resumeTask(fileInfo: NTDownloadTask) {
        if fileInfo.status == .NTFinishedDownload || fileInfo.status != .NTStopDownload {
            return
        }
        let downloadTask = fileInfo.task!
        downloadTask.resume()
        fileInfo.status = NTDownloadStatus(rawValue: downloadTask.state.rawValue)!
        fileInfo.delegate?.downloadTaskDownloading?(task: fileInfo)
        print(taskList[0])
    }
    /// 开始所有下载任务
    public func resumeAllTask() {
        for task in unFinishedList {
            resumeTask(fileInfo: task)
        }
    }
    /// 暂停所有下载任务
    public func pauseAllTask() {
        for task in unFinishedList {
            pauseTask(fileInfo: task)
        }
    }
    /// 返回已下载完成文件路径 若未下载完成 则返回 nil
    public func taskPath(fileInfo: NTDownloadTask) -> String? {
        if fileInfo.status != .NTFinishedDownload {
            return nil
        }
        return "\(documentPath)/\(fileInfo.fileName)"
    }
    /// 删除下载文件
    public func removeTask(fileInfo: NTDownloadTask) {
        for i in 0..<taskList.count {
            if (fileInfo.fileURL == taskList[i].fileURL) {
                if fileInfo.status == .NTFinishedDownload {
                    let path = "\(documentPath)/\(fileInfo.fileName)"
                    try? FileManager.default.removeItem(atPath: path)
                } else {
                    taskList[i].task?.cancel()
                }
                taskList.remove(at: i)
//                saveTaskList()
                break
            }
        }
    }
    /// 删除所有下载文件
    public func removeAllTask() {
        for task in taskList {
            if task.status == .NTFinishedDownload {
                let path = "\(documentPath)/\(task.fileName)"
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        try? FileManager.default.removeItem(atPath: plistPath)
    }
    
    public func clearTMP() {
        do {
            let tmpDirectory = try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory())
            try tmpDirectory.forEach { file in
                let path = String.init(format: "%@/%@", NSTemporaryDirectory(), file)
                try FileManager.default.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
}
// MARK: - 私有方法
private extension NTDownloadManager {
    func initDownloadTasks() {
        session.getTasksWithCompletionHandler { (_, _, downloadTasks) in
            for downloadTask in downloadTasks {
                guard let taskDescriptions = downloadTask.taskDescription?.components(separatedBy: ",") else {
                    continue
                }
                print(taskDescriptions)
                let fileURL = taskDescriptions[self.taskDescriptionFileURL]
                let fileName = taskDescriptions[self.taskDescriptionFileName]
                let fileImage = taskDescriptions[self.taskDescriptionFileImage]
                let url = URL(string: fileURL)!
                print(downloadTask.state)
                let task = NTDownloadTask(fileURL: url, fileName: fileName, taskIdentifier: 0, fileImage: fileImage, status: NTDownloadStatus(rawValue: downloadTask.state.rawValue)!)
                
                task.task = downloadTask
                self.taskList.append(task)
            }
        }
    }
    func loadTaskList() {
        guard let jsonArray = NSArray(contentsOfFile: plistPath) else {
            return
        }
        for jsonItem in jsonArray {
            guard let item = jsonItem as? NSDictionary, let fileName = item["fileName"] as? String, let urlString = item["fileURL"] as? String //let status = item["status"] as? NTDownloadStatus
            else {
                return
            }
              //let fileSize = item["fileSize"] as? size, let downloadedFileSize = item["downloadedFileSize"] as? size,
            let fileURL = URL(string: urlString)!
            let resumeData = item["resumeData"] as? Data
            let fileImage = item["fileImage"] as? String
            let task = NTDownloadTask(fileURL: fileURL, fileName: fileName, taskIdentifier: 0, fileImage: fileImage, status: .NTFinishedDownload)
//            task.fileSize = fileSize
//            task.downloadedFileSize = downloadedFileSize
            task.resumeData = resumeData
            self.taskList.append(task)
            if task.status != .NTFinishedDownload {
                guard let downloadTask = session?.downloadTask(with: task.fileURL) else {
                    continue
                }
                task.taskIdentifier = downloadTask.taskIdentifier
                downloadTask.cancel()
//                self.downloadTaskList.append(downloadTask)
                task.delegate?.downloadTaskStopDownload?(task: task)
//                self.saveTaskList()
            }
        }
    }
}
// MARK: - URLSessionDownloadDelegate
extension NTDownloadManager: URLSessionDownloadDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debugPrint("task id: \(task.taskIdentifier)")
        let error = error as NSError?
        if (error?.userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int) == NSURLErrorCancelledReasonUserForceQuitApplication || (error?.userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int) == NSURLErrorCancelledReasonBackgroundUpdatesDisabled {
            for downloadTask in unFinishedList {
                if downloadTask.fileURL == task.originalRequest?.url || downloadTask.fileURL == task.currentRequest?.url {
                    let resumeData = error?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                    downloadTask.resumeData = resumeData
                    resumeTask(fileInfo: downloadTask)
                }
            }
        }
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for task in unFinishedList {
            if downloadTask.isEqual(task.task) {
                task.status = .NTFinishedDownload
                let destUrl = documentUrl.appendingPathComponent(task.fileName)
                do {
                    try FileManager.default.moveItem(at: location, to: destUrl)
                } catch {
                    print(error)
                }
            }
        }
        // FIXME: 保存下载完成的项目
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        for task in unFinishedList {
            if downloadTask.isEqual(task.task) {
                DispatchQueue.main.async {
                    task.fileSize = (NTCommonHelper.calculateFileSize(totalBytesExpectedToWrite), NTCommonHelper.calculateUnit(totalBytesExpectedToWrite))
                    task.downloadedFileSize = (NTCommonHelper.calculateFileSize(totalBytesWritten),NTCommonHelper.calculateUnit(totalBytesWritten))
                    task.delegate?.downloadTaskUpdateProgress?(task: task, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                }
            }
        }
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {}
}
