/*
 *   Linux  :  gcc -o test load_so_from_memory.c -ldl
 *   FreeBSD:  cc  -o test load_so_from_memory.c
 *
 */
#define _GNU_SOURCE

#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

#if !defined(__linux__) && !defined(__FreeBSD__)
#  error "Only Linux and FreeBSD are supported"
#endif

typedef struct memlib {
    void *dl_handle;   /* result of dlopen / fdlopen */
    int   fd;          /* memfd on Linux, -1 on FreeBSD */
} memlib_t;

memlib_t *
load_library_from_memory(const void *bytes, size_t len)
{
    if (!bytes || len == 0)
        return NULL;

    memlib_t *lib = calloc(1, sizeof(*lib));
    if (!lib)
        return NULL;

    lib->fd = -1;          /* default for FreeBSD */

#ifdef __linux__
    /* ---- Linux ---------------------------------------------------- */
    int fd = memfd_create("lib_from_mem", MFD_CLOEXEC);
    if (fd == -1)
        goto fail;

    if (ftruncate(fd, (off_t)len) == -1) {
        close(fd);
        goto fail;
    }

    void *addr = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (addr == MAP_FAILED) {
        close(fd);
        goto fail;
    }
    memcpy(addr, bytes, len);
    munmap(addr, len);

    char path[64];
    snprintf(path, sizeof(path), "/proc/self/fd/%d", fd);

    lib->dl_handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!lib->dl_handle) {
        close(fd);
        goto fail;
    }

    /* Keep the fd alive for the lifetime of the handle.
     * This prevents the glibc path-cache collision that occurs when
     * the same numeric fd is later reused by another memfd_create.
     */
    lib->fd = fd;
    return lib;

#elif defined(__FreeBSD__)
    /* ---- FreeBSD -------------------------------------------------- */
    int fd = shm_open(SHM_ANON, O_RDWR, 0600);
    if (fd == -1)
        goto fail;

    if (ftruncate(fd, (off_t)len) == -1) {
        close(fd);
        goto fail;
    }

    void *addr = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (addr == MAP_FAILED) {
        close(fd);
        goto fail;
    }
    memcpy(addr, bytes, len);
    munmap(addr, len);

    lib->dl_handle = fdlopen(fd, RTLD_NOW | RTLD_LOCAL);
    close(fd);                 /* fdlopen duplicates; we may close now */
    if (!lib->dl_handle)
        goto fail;

    return lib;
#endif

fail:
    free(lib);
    return NULL;
}

void
unload_library_from_memory(memlib_t *lib)
{
    if (!lib)
        return;

    if (lib->dl_handle)
        dlclose(lib->dl_handle);

#ifdef __linux__
    /* The memfd must be closed only after dlclose has dropped its
     * reference.  Doing it here is safe and prevents any leak.
     */
    if (lib->fd >= 0)
        close(lib->fd);
#endif

    free(lib);
}

void *
memlib_dlsym(memlib_t *lib, const char *symbol)
{
    if (!lib || !lib->dl_handle || !symbol)
        return NULL;
    return dlsym(lib->dl_handle, symbol);
}



#ifdef TEST_MAIN

static void *
read_file(const char *path, size_t *out_len)
{
    FILE *f = fopen(path, "rb");
    if (!f) {
        perror(path);
        return NULL;
    }

    if (fseek(f, 0, SEEK_END) != 0) {
        perror("fseek");
        fclose(f);
        return NULL;
    }

    long sz = ftell(f);
    if (sz < 0) {
        perror("ftell");
        fclose(f);
        return NULL;
    }
    rewind(f);

    void *buf = malloc((size_t)sz);
    if (!buf) {
        perror("malloc");
        fclose(f);
        return NULL;
    }

    if (fread(buf, 1, (size_t)sz, f) != (size_t)sz) {
        perror("fread");
        free(buf);
        fclose(f);
        return NULL;
    }

    fclose(f);
    *out_len = (size_t)sz;
    return buf;
}

int
main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <path-to-shared-library.so>\n", argv[0]);
        fprintf(stderr, "Example: %s /lib/x86_64-linux-gnu/libc.so.6\n", argv[0]);
        return 1;
    }

    const char *path = argv[1];
    size_t len = 0;
    void *bytes = read_file(path, &len);
    if (!bytes)
        return 1;

    printf("Read %zu bytes from %s\n", len, path);

    memlib_t *lib = load_library_from_memory(bytes, len);
    free(bytes);               /* original buffer no longer needed */

    if (!lib) {
        fprintf(stderr, "load_library_from_memory failed: %s\n", dlerror());
        return 1;
    }

    printf("Library loaded successfully (handle %p)\n", (void *)lib);

    /* Optional: try to resolve a well-known symbol (works for libc/libm etc.) */
    void *sym = memlib_dlsym(lib, "malloc");
    if (sym)
        printf("Resolved symbol \"malloc\" → %p\n", sym);
    else
        printf("Symbol \"malloc\" not found (this is OK for many libraries)\n");

    unload_library_from_memory(lib);
    printf("Library unloaded cleanly\n");

    return 0;
}

#endif /* TEST_MAIN */

