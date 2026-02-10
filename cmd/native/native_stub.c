#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "moonbit.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

/* ================================================================
 * HTTP GET via curl subprocess
 * Returns: status_code (int), body written to provided buffer
 * ================================================================ */

/* Execute curl and capture output. Returns HTTP status code, -1 on error. */
static int curl_get(const char *url, const char *headers_str,
                    char **out_body, size_t *out_len) {
    /* Build curl command:
     * -s: silent, -w '\n%{http_code}': append status code after body
     * -L: follow redirects
     * -H: custom headers */
    size_t cmd_len = strlen(url) + strlen(headers_str) + 256;
    char *cmd = (char *)malloc(cmd_len);
    if (!cmd) return -1;

    snprintf(cmd, cmd_len,
             "curl -sL -w '\\n%%{http_code}' %s '%s' 2>/dev/null",
             headers_str, url);

    FILE *fp = popen(cmd, "r");
    free(cmd);
    if (!fp) return -1;

    /* Read all output into a dynamic buffer */
    size_t cap = 4096;
    size_t len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) { pclose(fp); return -1; }

    size_t n;
    while ((n = fread(buf + len, 1, cap - len, fp)) > 0) {
        len += n;
        if (len >= cap) {
            cap *= 2;
            char *newbuf = (char *)realloc(buf, cap);
            if (!newbuf) { free(buf); pclose(fp); return -1; }
            buf = newbuf;
        }
    }
    pclose(fp);

    if (len == 0) {
        free(buf);
        return -1;
    }

    /* Find the last newline — everything after it is the status code */
    buf[len] = '\0';
    char *last_nl = strrchr(buf, '\n');
    if (!last_nl || last_nl == buf) {
        /* No newline found or empty body — try to parse whole thing as status */
        free(buf);
        return -1;
    }

    int status = atoi(last_nl + 1);
    *last_nl = '\0'; /* Trim status code from body */
    size_t body_len = (size_t)(last_nl - buf);

    /* Copy body to moonbit bytes */
    *out_body = buf;
    *out_len = body_len;
    return status;
}

/* Build -H flags string from header pairs.
 * headers format: "Name1: Value1\nName2: Value2\n" */
static char *build_header_flags(const char *headers, size_t headers_len) {
    if (headers_len == 0) {
        char *empty = (char *)malloc(1);
        empty[0] = '\0';
        return empty;
    }

    /* Worst case: each header gets -H '...' wrapper */
    size_t cap = headers_len * 2 + 256;
    char *result = (char *)malloc(cap);
    if (!result) return NULL;
    result[0] = '\0';

    const char *p = headers;
    const char *end = headers + headers_len;
    while (p < end) {
        const char *nl = memchr(p, '\n', end - p);
        if (!nl) nl = end;
        if (nl > p) {
            size_t hdr_len = nl - p;
            char *hdr = (char *)malloc(hdr_len + 1);
            memcpy(hdr, p, hdr_len);
            hdr[hdr_len] = '\0';

            size_t cur_len = strlen(result);
            snprintf(result + cur_len, cap - cur_len, "-H '%s' ", hdr);
            free(hdr);
        }
        p = nl + 1;
    }
    return result;
}

/* MoonBit FFI: http_get_ffi(url_bytes, headers_bytes) -> status_code
 * Body is stored internally and retrieved via http_get_body_ffi() */
static char *g_last_body = NULL;
static size_t g_last_body_len = 0;

MOONBIT_FFI_EXPORT
int32_t checksum_http_get(moonbit_bytes_t url_bytes, moonbit_bytes_t headers_bytes) {
    /* Free previous body */
    if (g_last_body) { free(g_last_body); g_last_body = NULL; g_last_body_len = 0; }

    size_t url_len = Moonbit_array_length(url_bytes);
    char *url = (char *)malloc(url_len + 1);
    memcpy(url, (const char *)url_bytes, url_len);
    url[url_len] = '\0';

    size_t hdr_len = Moonbit_array_length(headers_bytes);
    char *hdr_str = NULL;
    if (hdr_len > 0) {
        char *hdrs = (char *)malloc(hdr_len + 1);
        memcpy(hdrs, (const char *)headers_bytes, hdr_len);
        hdrs[hdr_len] = '\0';
        hdr_str = build_header_flags(hdrs, hdr_len);
        free(hdrs);
    } else {
        hdr_str = (char *)malloc(1);
        hdr_str[0] = '\0';
    }

    char *body = NULL;
    size_t body_len = 0;
    int status = curl_get(url, hdr_str, &body, &body_len);

    free(url);
    free(hdr_str);

    if (status < 0) {
        return -1;
    }

    g_last_body = body;
    g_last_body_len = body_len;
    return status;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t checksum_http_get_body(void) {
    if (!g_last_body || g_last_body_len == 0) {
        return moonbit_make_bytes(0, 0);
    }
    moonbit_bytes_t result = moonbit_make_bytes(g_last_body_len, 0);
    memcpy(result, g_last_body, g_last_body_len);
    return result;
}

/* ================================================================
 * Sleep (milliseconds)
 * ================================================================ */

MOONBIT_FFI_EXPORT
void checksum_sleep_ms(int32_t ms) {
#ifdef _WIN32
    Sleep((DWORD)ms);
#else
    usleep((useconds_t)ms * 1000);
#endif
}

/* ================================================================
 * Get GitHub auth token via `gh auth token` CLI
 * Returns token as bytes, or empty bytes if unavailable.
 * ================================================================ */

MOONBIT_FFI_EXPORT
moonbit_bytes_t checksum_get_gh_token(void) {
#ifdef _WIN32
    FILE *fp = _popen("gh auth token 2>nul", "r");
#else
    FILE *fp = popen("gh auth token 2>/dev/null", "r");
#endif
    if (!fp) {
        return moonbit_make_bytes(0, 0);
    }
    char buf[256];
    size_t len = fread(buf, 1, sizeof(buf) - 1, fp);
#ifdef _WIN32
    int status = _pclose(fp);
#else
    int status = pclose(fp);
#endif
    if (status != 0 || len == 0) {
        return moonbit_make_bytes(0, 0);
    }
    /* Trim trailing whitespace/newline */
    while (len > 0 && (buf[len-1] == '\n' || buf[len-1] == '\r'
                       || buf[len-1] == ' ')) {
        len--;
    }
    moonbit_bytes_t result = moonbit_make_bytes(len, 0);
    memcpy(result, buf, len);
    return result;
}
