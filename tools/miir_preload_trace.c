#define _GNU_SOURCE
#include <dlfcn.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void* MiirHandle;
typedef int MiirStatus;

static pthread_once_t g_once = PTHREAD_ONCE_INIT;

static MiirHandle (*real_miirCreateHandle)(const char* arguments) = NULL;
static MiirStatus (*real_miirDestroyHandle)(MiirHandle handle) = NULL;
static MiirStatus (*real_miirLowerTuningParams)(MiirHandle handle) = NULL;
static MiirStatus (*real_miirLowerBin)(MiirHandle handle) = NULL;
static int (*real_miirGetKernelCount)(MiirHandle handle) = NULL;
static int (*real_miirGetWorkspaceSize)(MiirHandle handle) = NULL;
static MiirStatus (*real_miirGetExecutionDims)(MiirHandle handle, size_t* globalSize, size_t* localSize) = NULL;

static void resolve_symbols(void) {
    real_miirCreateHandle = (MiirHandle(*)(const char*))dlsym(RTLD_NEXT, "miirCreateHandle");
    real_miirDestroyHandle = (MiirStatus(*)(MiirHandle))dlsym(RTLD_NEXT, "miirDestroyHandle");
    real_miirLowerTuningParams = (MiirStatus(*)(MiirHandle))dlsym(RTLD_NEXT, "miirLowerTuningParams");
    real_miirLowerBin = (MiirStatus(*)(MiirHandle))dlsym(RTLD_NEXT, "miirLowerBin");
    real_miirGetKernelCount = (int(*)(MiirHandle))dlsym(RTLD_NEXT, "miirGetKernelCount");
    real_miirGetWorkspaceSize = (int(*)(MiirHandle))dlsym(RTLD_NEXT, "miirGetWorkspaceSize");
    real_miirGetExecutionDims = (MiirStatus(*)(MiirHandle, size_t*, size_t*))dlsym(RTLD_NEXT, "miirGetExecutionDims");
}

static void ensure_symbols(void) {
    pthread_once(&g_once, resolve_symbols);
}

static void copy_argument_preview(const char* src, char* dst, size_t dst_size) {
    size_t i = 0;
    if (dst_size == 0) {
        return;
    }
    if (src == NULL) {
        snprintf(dst, dst_size, "<null>");
        return;
    }
    for (; src[i] != '\0' && i + 1 < dst_size; ++i) {
        char c = src[i];
        dst[i] = (c == '\n' || c == '\r' || c == '\t') ? ' ' : c;
    }
    dst[i] = '\0';
}

MiirHandle miirCreateHandle(const char* arguments) {
    char arg_preview[2048];
    MiirHandle handle;

    ensure_symbols();
    copy_argument_preview(arguments, arg_preview, sizeof(arg_preview));

    if (real_miirCreateHandle == NULL) {
        fprintf(stderr, "[MIIR_TRACE] miirCreateHandle symbol resolve failed\n");
        return NULL;
    }

    handle = real_miirCreateHandle(arguments);
    fprintf(stderr, "[MIIR_TRACE] miirCreateHandle ret=%p args=\"%s\"\n", handle, arg_preview);
    return handle;
}

MiirStatus miirDestroyHandle(MiirHandle handle) {
    MiirStatus status;
    ensure_symbols();
    if (real_miirDestroyHandle == NULL) {
        fprintf(stderr, "[MIIR_TRACE] miirDestroyHandle symbol resolve failed\n");
        return 1;
    }
    status = real_miirDestroyHandle(handle);
    fprintf(stderr, "[MIIR_TRACE] miirDestroyHandle h=%p status=%d\n", handle, status);
    return status;
}

MiirStatus miirLowerTuningParams(MiirHandle handle) {
    MiirStatus status;
    ensure_symbols();
    if (real_miirLowerTuningParams == NULL) {
        fprintf(stderr, "[MIIR_TRACE] miirLowerTuningParams symbol resolve failed\n");
        return 1;
    }
    status = real_miirLowerTuningParams(handle);
    fprintf(stderr, "[MIIR_TRACE] miirLowerTuningParams h=%p status=%d\n", handle, status);
    return status;
}

MiirStatus miirLowerBin(MiirHandle handle) {
    MiirStatus status;
    ensure_symbols();
    if (real_miirLowerBin == NULL) {
        fprintf(stderr, "[MIIR_TRACE] miirLowerBin symbol resolve failed\n");
        return 1;
    }
    status = real_miirLowerBin(handle);
    fprintf(stderr, "[MIIR_TRACE] miirLowerBin h=%p status=%d\n", handle, status);
    return status;
}

int miirGetKernelCount(MiirHandle handle) {
    int count;
    ensure_symbols();
    if (real_miirGetKernelCount == NULL) {
        fprintf(stderr, "[MIIR_TRACE] miirGetKernelCount symbol resolve failed\n");
        return -1;
    }
    count = real_miirGetKernelCount(handle);
    fprintf(stderr, "[MIIR_TRACE] miirGetKernelCount h=%p count=%d\n", handle, count);
    return count;
}

int miirGetWorkspaceSize(MiirHandle handle) {
    int ws;
    ensure_symbols();
    if (real_miirGetWorkspaceSize == NULL) {
        fprintf(stderr, "[MIIR_TRACE] miirGetWorkspaceSize symbol resolve failed\n");
        return 0;
    }
    ws = real_miirGetWorkspaceSize(handle);
    fprintf(stderr, "[MIIR_TRACE] miirGetWorkspaceSize h=%p ws=%d\n", handle, ws);
    return ws;
}

MiirStatus miirGetExecutionDims(MiirHandle handle, size_t* globalSize, size_t* localSize) {
    MiirStatus status;
    ensure_symbols();
    if (real_miirGetExecutionDims == NULL) {
        fprintf(stderr, "[MIIR_TRACE] miirGetExecutionDims symbol resolve failed\n");
        return 1;
    }
    status = real_miirGetExecutionDims(handle, globalSize, localSize);
    fprintf(stderr,
            "[MIIR_TRACE] miirGetExecutionDims h=%p status=%d g=%zu l=%zu\n",
            handle,
            status,
            globalSize ? *globalSize : 0,
            localSize ? *localSize : 0);
    return status;
}
