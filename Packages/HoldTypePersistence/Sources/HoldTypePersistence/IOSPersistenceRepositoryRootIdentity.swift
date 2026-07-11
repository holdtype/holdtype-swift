import Darwin

/// Physical identity of the app-support root that a descriptor-relative
/// repository operation is authorized to consume.
struct IOSPersistenceRepositoryRootIdentity: Equatable, Sendable {
    let device: dev_t
    let inode: ino_t

    func matches(_ status: stat) -> Bool {
        status.st_dev == device && status.st_ino == inode
    }
}
