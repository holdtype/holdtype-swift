#define _DARWIN_C_SOURCE 1
#include <errno.h>
#include <fcntl.h>
#include <pwd.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

enum probe_status { PROBE_OK = 0, PROBE_UNCERTAIN = 65 };

static bool same_identity(const struct stat *a, const struct stat *b) {
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino &&
        (a->st_mode & (S_IFMT | 07777)) == (b->st_mode & (S_IFMT | 07777)) &&
        a->st_uid == b->st_uid && a->st_gid == b->st_gid && a->st_nlink == b->st_nlink;
}

static bool system_directory(const struct stat *value) {
    mode_t perms = value->st_mode & 07777;
    return (value->st_mode & S_IFMT) == S_IFDIR && value->st_uid == 0 &&
        (perms & 0555) == 0555 && (perms & 0022) == 0 && (perms & 07000) == 0;
}

static bool user_directory(const struct stat *value, uid_t uid) {
    mode_t perms = value->st_mode & 07777;
    return (value->st_mode & S_IFMT) == S_IFDIR && value->st_uid == uid &&
        (perms & 0700) == 0700 && (perms & 0022) == 0 && (perms & 07000) == 0;
}

static bool recovery_index(const struct stat *value, uid_t uid) {
    mode_t perms = value->st_mode & 07777;
    return (value->st_mode & S_IFMT) == S_IFREG && value->st_uid == uid &&
        value->st_nlink == 1 && (perms & 0600) == 0600 &&
        (perms & 0022) == 0 && (perms & 07111) == 0;
}

static int open_checked_directory(int parent, const char *name, uid_t uid,
                                  bool system_owned, int *result) {
    struct stat before, after;
    if (fstatat(parent, name, &before, AT_SYMLINK_NOFOLLOW) != 0) return errno == ENOENT ? 1 : -1;
    if (!(system_owned ? system_directory(&before) : user_directory(&before, uid))) return -1;
    int fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0 || fstat(fd, &after) != 0 || !same_identity(&before, &after)) {
        if (fd >= 0) close(fd);
        return -1;
    }
    *result = fd;
    memset(&before, 0, sizeof(before));
    memset(&after, 0, sizeof(after));
    return 0;
}

static void print_tuple(char tag, const struct stat *value) {
    printf("%c|P|%llu|%llu|%o|%u|%u|%u|%lld|%lld|%ld\n", tag,
           (unsigned long long)value->st_dev, (unsigned long long)value->st_ino,
           value->st_mode & (S_IFMT | 07777), value->st_uid, value->st_gid,
           (unsigned)value->st_nlink, (long long)value->st_size,
           (long long)value->st_mtimespec.tv_sec, value->st_mtimespec.tv_nsec);
}

static int canonical_user(char *name, size_t capacity, const char **root_path) {
#ifdef HTDV_PROBE_SYNTHETIC
    const char *fixture_root = getenv("HTDV_PROBE_FIXTURE_ROOT");
    const char *fixture_user = getenv("HTDV_PROBE_FIXTURE_USER");
    if (fixture_root == NULL || fixture_user == NULL || fixture_user[0] == '\0' ||
        strchr(fixture_user, '/') != NULL || strcmp(fixture_user, ".") == 0 ||
        strcmp(fixture_user, "..") == 0 || strlen(fixture_user) >= capacity) return -1;
    strcpy(name, fixture_user);
    *root_path = fixture_root;
    return 0;
#else
    uid_t uid = geteuid();
    long hint = sysconf(_SC_GETPW_R_SIZE_MAX);
    size_t size = hint > 0 ? (size_t)hint : 16384;
    char *buffer = calloc(1, size);
    struct passwd entry, *found = NULL;
    if (buffer == NULL || getpwuid_r(uid, &entry, buffer, size, &found) != 0 || found == NULL) {
        free(buffer);
        return -1;
    }
    const char *prefix = "/Users/";
    const char *component = entry.pw_dir;
    if (strncmp(component, prefix, strlen(prefix)) != 0) { free(buffer); return -1; }
    component += strlen(prefix);
    if (component[0] == '\0' || strchr(component, '/') != NULL || strcmp(component, ".") == 0 ||
        strcmp(component, "..") == 0 || strlen(component) >= capacity) { free(buffer); return -1; }
    strcpy(name, component);
    *root_path = "/";
    memset(buffer, 0, size);
    free(buffer);
    return 0;
#endif
}

int main(void) {
    uid_t uid = geteuid();
    char user[256] = {0};
    const char *root_path = NULL;
    struct stat root_before, root_after, directory_value, index_value;
    int root = -1, users = -1, home = -1, current = -1;
    int status = PROBE_UNCERTAIN;
    bool directory_missing = false;
    if (canonical_user(user, sizeof(user), &root_path) != 0) goto done;
    if (lstat(root_path, &root_before) != 0) goto done;
#ifdef HTDV_PROBE_SYNTHETIC
    if (!user_directory(&root_before, uid)) goto done;
#else
    if (!system_directory(&root_before)) goto done;
#endif
    root = open(root_path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (root < 0 || fstat(root, &root_after) != 0 || !same_identity(&root_before, &root_after)) goto done;
#ifdef HTDV_PROBE_SYNTHETIC
    if (open_checked_directory(root, "Users", uid, false, &users) != 0) goto done;
#else
    if (open_checked_directory(root, "Users", uid, true, &users) != 0) goto done;
#endif
    if (open_checked_directory(users, user, uid, false, &home) != 0) goto done;
    current = home;
    const char *components[] = {"Library", "Application Support", "HoldType", "TranscriptionRecovery"};
    for (size_t i = 0; i < sizeof(components) / sizeof(components[0]); i++) {
        int next = -1;
        int outcome = open_checked_directory(current, components[i], uid, false, &next);
        if (outcome == 1) { directory_missing = true; break; }
        if (outcome != 0) goto done;
        if (current != home) close(current);
        current = next;
    }
    if (directory_missing) {
        printf("D|M\nI|M\n");
        status = PROBE_OK;
        goto done;
    }
    if (fstat(current, &directory_value) != 0 || !user_directory(&directory_value, uid)) goto done;
    print_tuple('D', &directory_value);
    if (fstatat(current, "Recovery.json", &index_value, AT_SYMLINK_NOFOLLOW) != 0) {
        if (errno != ENOENT) goto done;
        printf("I|M\n");
    } else {
        if (!recovery_index(&index_value, uid)) goto done;
        print_tuple('I', &index_value);
    }
    status = PROBE_OK;
done:
    if (current >= 0 && current != home) close(current);
    if (home >= 0) close(home);
    if (users >= 0) close(users);
    if (root >= 0) close(root);
    memset(user, 0, sizeof(user));
    memset(&root_before, 0, sizeof(root_before));
    memset(&root_after, 0, sizeof(root_after));
    memset(&directory_value, 0, sizeof(directory_value));
    memset(&index_value, 0, sizeof(index_value));
    return status;
}
