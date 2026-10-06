// BetterSpellWheel client installer for RuneScape: Dragonwilds (Windows).
//
// Double-click: finds the game through Steam, installs UE4SS only if no UE4SS is present, and adds
// the BetterSpellWheel mod next to any other mods. Run again to update or uninstall.
//
// The files to install are appended to this exe by installer/build.py:
//   [stub exe][entries...][u64 payload offset]["BSWPAY01"]
//   entry = u32 name length, name (UTF-8, '/' separated), u64 size, bytes
//
// Command line (for scripting and tests):
//   /silent        no dialogs; result in the log and the exit code (0 = ok)
//   /dir=PATH      game folder (the one containing RSDragonwilds\), skips Steam detection
//   /uninstall     remove BetterSpellWheel (and UE4SS if this installer added it and nothing else uses it)
//   /detect        only report the game folder that would be used
//
// Log: %TEMP%\BetterSpellWheel-install.log
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shlobj.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <stdarg.h>

#define TITLE L"BetterSpellWheel installer"
#define APP_ID L"1374490"
#define MOD L"BetterSpellWheel"
#define MARKER L".installed-by-betterspellwheel"

static int silent = 0;
static FILE *logFile = NULL;
static wchar_t version[32] = L"?";

// ------------------------------------------------------------------ log and dialogs

static void lg(const wchar_t *fmt, ...)
{
    va_list ap;
    if (logFile) { va_start(ap, fmt); vfwprintf(logFile, fmt, ap); va_end(ap); fputwc(L'\n', logFile); fflush(logFile); }
}

static int box(const wchar_t *msg, UINT flags, int silentAnswer)
{
    if (silent) return silentAnswer;
    return MessageBoxW(NULL, msg, TITLE, flags | MB_SETFOREGROUND);
}

static int fail(const wchar_t *msg)
{
    lg(L"ERROR: %ls", msg);
    box(msg, MB_OK | MB_ICONERROR, 0);
    return 1;
}

// ------------------------------------------------------------------ files

static int exists(const wchar_t *p) { return GetFileAttributesW(p) != INVALID_FILE_ATTRIBUTES; }
static int isDir(const wchar_t *p) { DWORD a = GetFileAttributesW(p); return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY); }

static void join(wchar_t *out, const wchar_t *a, const wchar_t *b)
{
    swprintf(out, MAX_PATH * 2, L"%ls%ls%ls", a, (a[0] && a[wcslen(a) - 1] != L'\\') ? L"\\" : L"", b);
}

static void parentDir(const wchar_t *path, wchar_t *out)
{
    wcscpy(out, path);
    wchar_t *s = wcsrchr(out, L'\\');
    if (s) *s = 0;
}

static int mkdirs(const wchar_t *dir)
{
    if (isDir(dir)) return 1;
    int r = SHCreateDirectoryExW(NULL, dir, NULL);
    return r == ERROR_SUCCESS || r == ERROR_ALREADY_EXISTS || r == ERROR_FILE_EXISTS;
}

static int writeFile(const wchar_t *path, const unsigned char *data, unsigned long long size)
{
    wchar_t dir[MAX_PATH * 2], tmp[MAX_PATH * 2];
    parentDir(path, dir);
    if (!mkdirs(dir)) { lg(L"cannot create %ls", dir); return 0; }
    swprintf(tmp, MAX_PATH * 2, L"%ls.bsw-new", path);
    HANDLE h = CreateFileW(tmp, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) { lg(L"cannot write %ls (%lu)", tmp, GetLastError()); return 0; }
    DWORD w = 0;
    BOOL ok = WriteFile(h, data, (DWORD)size, &w, NULL) && w == size;
    CloseHandle(h);
    if (!ok || !MoveFileExW(tmp, path, MOVEFILE_REPLACE_EXISTING)) {
        lg(L"cannot write %ls (%lu)", path, GetLastError());
        DeleteFileW(tmp);
        return 0;
    }
    return 1;
}

// Whole file as bytes (NUL-terminated); caller frees
static char *readAll(const wchar_t *path, DWORD *len)
{
    HANDLE h = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
    if (h == INVALID_HANDLE_VALUE) return NULL;
    DWORD size = GetFileSize(h, NULL), r = 0;
    char *buf = (char *)malloc(size + 1);
    if (buf && ReadFile(h, buf, size, &r, NULL)) { buf[r] = 0; if (len) *len = r; }
    else { free(buf); buf = NULL; }
    CloseHandle(h);
    return buf;
}

static void removeTree(const wchar_t *dir)
{
    wchar_t pat[MAX_PATH * 2], p[MAX_PATH * 2];
    WIN32_FIND_DATAW fd;
    join(pat, dir, L"*");
    HANDLE f = FindFirstFileW(pat, &fd);
    if (f != INVALID_HANDLE_VALUE) {
        do {
            if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L"..")) continue;
            join(p, dir, fd.cFileName);
            if (fd.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) { RemoveDirectoryW(p); DeleteFileW(p); continue; }   // never follow links
            if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) removeTree(p);
            else { SetFileAttributesW(p, FILE_ATTRIBUTE_NORMAL); DeleteFileW(p); }
        } while (FindNextFileW(f, &fd));
        FindClose(f);
    }
    RemoveDirectoryW(dir);
}

// ------------------------------------------------------------------ payload

typedef struct { char name[260]; const unsigned char *data; unsigned long long size; } Entry;
static Entry entries[256];
static int entryCount = 0;
static unsigned char *payload = NULL;

static int loadPayload(void)
{
    wchar_t self[MAX_PATH * 2];
    GetModuleFileNameW(NULL, self, MAX_PATH * 2);
    DWORD len = 0;
    char *all = readAll(self, &len);
    if (!all || len < 16 || memcmp(all + len - 8, "BSWPAY01", 8)) { free(all); return 0; }
    unsigned long long off;
    memcpy(&off, all + len - 16, 8);
    if (off >= len - 16) { free(all); return 0; }
    payload = (unsigned char *)all;
    unsigned long long p = off, end = len - 16;
    while (p + 4 <= end && entryCount < 256) {
        unsigned int nl; memcpy(&nl, payload + p, 4); p += 4;
        if (!nl || nl >= 260 || p + nl + 8 > end) return 0;
        Entry *e = &entries[entryCount++];
        memcpy(e->name, payload + p, nl); e->name[nl] = 0; p += nl;
        if (memchr(e->name, 0, nl) || e->name[0] == '/' || strchr(e->name, '\\') ||
            strchr(e->name, ':') || strstr(e->name, "..")) return 0;
        for (int j = 0; j < entryCount - 1; j++) if (!strcmp(entries[j].name, e->name)) return 0;
        memcpy(&e->size, payload + p, 8); p += 8;
        if (e->size > end - p) return 0;
        e->data = payload + p; p += e->size;
    }
    return entryCount > 0 && p == end;
}

static const Entry *entry(const char *name)
{
    for (int i = 0; i < entryCount; i++) if (!strcmp(entries[i].name, name)) return &entries[i];
    return NULL;
}

// Install payload entry "name" to dir\relative (relative uses '\')
static int put(const char *name, const wchar_t *dir, const wchar_t *relative)
{
    const Entry *e = entry(name);
    wchar_t path[MAX_PATH * 2];
    join(path, dir, relative);
    if (!e) { lg(L"payload is missing %hs", name); return 0; }
    if (!writeFile(path, e->data, e->size)) return 0;
    lg(L"wrote %ls", path);
    return 1;
}

// ------------------------------------------------------------------ finding the game

static int isGameDir(const wchar_t *dir)
{
    wchar_t p[MAX_PATH * 2];
    join(p, dir, L"RSDragonwilds\\Binaries\\Win64\\RSDragonwilds-Win64-Shipping.exe");
    return exists(p);
}

// Value of "key" "value" in a Steam .vdf/.acf text (first match after *from)
static int vdfValue(const char *text, const char *key, char *out, size_t cap, const char **from)
{
    char pat[64];
    snprintf(pat, sizeof pat, "\"%s\"", key);
    const char *s = strstr(from && *from ? *from : text, pat);
    if (!s) return 0;
    s += strlen(pat);
    s = strchr(s, '"');
    if (!s) return 0;
    s++;
    size_t n = 0;
    while (*s && *s != '"' && n + 1 < cap) {
        if (*s == '\\' && s[1] == '\\') s++;   // vdf escapes backslashes
        out[n++] = *s++;
    }
    out[n] = 0;
    if (from) *from = s;
    return 1;
}

static int checkLibrary(const wchar_t *lib, wchar_t *game)
{
    wchar_t acf[MAX_PATH * 2], common[MAX_PATH * 2];
    swprintf(acf, MAX_PATH * 2, L"%ls\\steamapps\\appmanifest_%ls.acf", lib, APP_ID);
    char *text = readAll(acf, NULL);
    if (text) {
        char dir[MAX_PATH];
        if (vdfValue(text, "installdir", dir, sizeof dir, NULL)) {
            wchar_t wdir[MAX_PATH];
            MultiByteToWideChar(CP_UTF8, 0, dir, -1, wdir, MAX_PATH);
            swprintf(game, MAX_PATH * 2, L"%ls\\steamapps\\common\\%ls", lib, wdir);
            free(text);
            if (isGameDir(game)) return 1;
        } else free(text);
    }
    swprintf(common, MAX_PATH * 2, L"%ls\\steamapps\\common\\RSDragonwilds", lib);
    if (isGameDir(common)) { wcscpy(game, common); return 1; }
    return 0;
}

static void slashes(wchar_t *p) { for (; *p; p++) if (*p == L'/') *p = L'\\'; }

static int findGame(wchar_t *game)
{
    wchar_t steam[MAX_PATH * 2] = L"";
    DWORD sz = sizeof steam;
    if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\Valve\\Steam", L"SteamPath", RRF_RT_REG_SZ, NULL, steam, &sz) != ERROR_SUCCESS) {
        sz = sizeof steam;
        RegGetValueW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\WOW6432Node\\Valve\\Steam", L"InstallPath", RRF_RT_REG_SZ, NULL, steam, &sz);
    }
    slashes(steam);
    lg(L"Steam: %ls", steam[0] ? steam : L"(not found)");
    if (steam[0]) {
        if (checkLibrary(steam, game)) return 1;
        wchar_t vdf[MAX_PATH * 2];
        join(vdf, steam, L"steamapps\\libraryfolders.vdf");
        char *text = readAll(vdf, NULL);
        if (text) {
            const char *at = text;
            char lib[MAX_PATH];
            while (vdfValue(text, "path", lib, sizeof lib, &at)) {
                wchar_t wlib[MAX_PATH * 2];
                MultiByteToWideChar(CP_UTF8, 0, lib, -1, wlib, MAX_PATH * 2);
                slashes(wlib);
                lg(L"Steam library: %ls", wlib);
                if (checkLibrary(wlib, game)) { free(text); return 1; }
            }
            free(text);
        }
    }
    return 0;
}

// Let the user point at the game folder (accepts the game folder or anything inside it)
static int browseForGame(wchar_t *game)
{
    BROWSEINFOW bi = { 0 };
    bi.lpszTitle = L"Couldn't find RuneScape: Dragonwilds automatically.\nChoose the game's folder (it contains the RSDragonwilds folder).";
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
    for (;;) {
        PIDLIST_ABSOLUTE pidl = SHBrowseForFolderW(&bi);
        if (!pidl) return 0;
        wchar_t dir[MAX_PATH * 2];
        int ok = SHGetPathFromIDListW(pidl, dir);
        CoTaskMemFree(pidl);
        if (!ok) return 0;
        // walk up from whatever was picked until the game folder is found
        for (int i = 0; i < 5 && dir[0]; i++) {
            if (isGameDir(dir)) { wcscpy(game, dir); return 1; }
            wchar_t up[MAX_PATH * 2]; parentDir(dir, up);
            if (!wcscmp(up, dir)) break;
            wcscpy(dir, up);
        }
        if (box(L"That folder doesn't contain RuneScape: Dragonwilds. Try again?", MB_RETRYCANCEL | MB_ICONWARNING, IDCANCEL) != IDRETRY) return 0;
    }
}

static int gameRunning(void)
{
    HANDLE s = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    PROCESSENTRY32W pe = { sizeof pe };
    int found = 0;
    if (s == INVALID_HANDLE_VALUE) return 0;
    for (BOOL more = Process32FirstW(s, &pe); more; more = Process32NextW(s, &pe))
        if (!_wcsicmp(pe.szExeFile, L"RSDragonwilds-Win64-Shipping.exe")) found = 1;
    CloseHandle(s);
    return found;
}

// ------------------------------------------------------------------ mods.txt

// Make mods.txt contain "BetterSpellWheel : 1" (or remove the line), leaving every other line alone
static int updateModsTxt(const wchar_t *modsDir, int add)
{
    wchar_t path[MAX_PATH * 2];
    join(path, modsDir, L"mods.txt");
    DWORD len = 0;
    char *text = readAll(path, &len);
    if (!text && !add) return 1;
    size_t cap = (text ? len : 0) + 256;
    char *out = (char *)malloc(cap);
    size_t n = 0;
    int done = 0, inserted = 0;
    const char *line = text ? text : "";
    const char *ourLine = "BetterSpellWheel : 1\r\n";
    while (*line) {
        const char *eol = strchr(line, '\n');
        size_t ll = eol ? (size_t)(eol - line + 1) : strlen(line);
        const char *t = line;
        while (*t == ' ' || *t == '\t' || (unsigned char)*t == 0xEF || (unsigned char)*t == 0xBB || (unsigned char)*t == 0xBF) t++;
        size_t ml = strlen("BetterSpellWheel");
        int ours = !_strnicmp(t, "BetterSpellWheel", ml) &&
            (t[ml] == ' ' || t[ml] == ':' || t[ml] == '\t' || t[ml] == '\r' || t[ml] == '\n' || !t[ml]);
        // keep UE4SS's built-in Keybinds entry last, as its own mods.txt asks
        int keybindsBlock = !_strnicmp(t, "; Built-in keybinds", 19) || !_strnicmp(t, "Keybinds", 8);
        if (add && !done && keybindsBlock) {
            memcpy(out + n, ourLine, strlen(ourLine)); n += strlen(ourLine); done = inserted = 1;
        }
        if (ours) {
            if (add && !done) { memcpy(out + n, ourLine, strlen(ourLine)); n += strlen(ourLine); done = 1; }
        } else {
            memcpy(out + n, line, ll); n += ll;
        }
        line += ll;
    }
    if (add && !done) {
        if (n && out[n - 1] != '\n') { out[n++] = '\r'; out[n++] = '\n'; }
        memcpy(out + n, ourLine, strlen(ourLine)); n += strlen(ourLine);
    }
    int ok = writeFile(path, (unsigned char *)out, n);
    lg(L"%ls %ls (%ls)", ok ? L"updated" : L"could not update", path, add ? (inserted ? L"added before Keybinds" : L"BetterSpellWheel : 1") : L"removed BetterSpellWheel");
    free(out); free(text);
    return ok;
}

// ------------------------------------------------------------------ install / uninstall

typedef struct { wchar_t win64[MAX_PATH * 2], modsDir[MAX_PATH * 2], modDir[MAX_PATH * 2]; int hasUe4ss, legacy; } Layout;

static void layoutOf(const wchar_t *game, Layout *L)
{
    wchar_t p[MAX_PATH * 2];
    join(L->win64, game, L"RSDragonwilds\\Binaries\\Win64");
    L->legacy = 0;
    join(p, L->win64, L"ue4ss\\UE4SS.dll");
    L->hasUe4ss = exists(p);
    if (L->hasUe4ss) join(L->modsDir, L->win64, L"ue4ss\\Mods");
    else {
        join(p, L->win64, L"UE4SS.dll");            // UE4SS 2.x keeps everything next to the game exe
        if (exists(p)) { L->hasUe4ss = 1; L->legacy = 1; join(L->modsDir, L->win64, L"Mods"); }
        else join(L->modsDir, L->win64, L"ue4ss\\Mods");
    }
    join(L->modDir, L->modsDir, MOD);
}

static int linkedPath(const wchar_t *path)
{
    wchar_t p[MAX_PATH * 2];
    wcscpy(p, path);
    while (wcslen(p) > 3) {
        DWORD a = GetFileAttributesW(p);
        if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_REPARSE_POINT)) return 1;
        wchar_t *sep = wcsrchr(p, L'\\');
        if (!sep) break;
        *sep = 0;
    }
    return 0;
}

static int validateTarget(const Layout *L)
{
    if (linkedPath(L->modDir)) return fail(L"The install path contains a junction or symbolic link. Use a regular game folder for installation.");
    for (int i = 0; i < entryCount; i++) {
        const char *prefix = "BetterSpellWheel/";
        if (strncmp(entries[i].name, prefix, strlen(prefix))) continue;
        wchar_t rel[260], path[MAX_PATH * 2];
        if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, entries[i].name + strlen(prefix), -1, rel, 260)) return 1;
        slashes(rel); join(path, L->modDir, rel);
        if (linkedPath(path)) return fail(L"An installed mod file is a junction or symbolic link. No files were changed.");
    }
    return 0;
}

static int install(const wchar_t *game)
{
    Layout L;
    layoutOf(game, &L);
    wchar_t p[MAX_PATH * 2], msg[2048], ue4ssNote[256];
    if (validateTarget(&L)) return 1;
    join(p, L.modsDir, L"SpellBranches");
    if (exists(p)) return fail(L"The older SpellBranches mod is installed. Close the game, remove its mod folder and mods.txt entry, then run BetterSpellWheel setup again. This avoids loading both wheels together.");
    if (L.hasUe4ss) {
        swprintf(ue4ssNote, 256, L"UE4SS was already installed%ls and was left as it is.", L.legacy ? L" (2.x layout)" : L"");
        lg(L"UE4SS present (%ls), mods in %ls", L.legacy ? L"legacy" : L"ue4ss folder", L.modsDir);
    } else {
        join(p, L.win64, L"dwmapi.dll");
        if (exists(p))
            return fail(L"Another mod loader's dwmapi.dll is already in the game folder, so UE4SS can't be installed without replacing it.\n\nNothing was changed. Install UE4SS for Dragonwilds yourself, then run this installer again.");
        wchar_t ue[MAX_PATH * 2];
        join(ue, L.win64, L"ue4ss");
        if (!put("UE4SS.dll", ue, L"UE4SS.dll") || !put("UE4SS-settings.ini", ue, L"UE4SS-settings.ini") || !put("UE4SS-LICENSE.txt", ue, L"UE4SS-LICENSE.txt"))
            return fail(L"Couldn't write UE4SS into the game folder. Is the game still running, or the folder read-only?");
        join(p, ue, MARKER);
        { static const char note[] = "UE4SS was installed by the BetterSpellWheel installer.\r\n"; writeFile(p, (const unsigned char *)note, sizeof note - 1); }
        if (!put("dwmapi.dll", L.win64, L"dwmapi.dll"))   // last: the loader only goes in once UE4SS is complete
            return fail(L"Couldn't write dwmapi.dll into the game folder.");
        wcscpy(ue4ssNote, L"UE4SS (the mod loader) was installed too.");
    }
    join(p, L.modDir, L"config.txt");
    int keptConfig = exists(p);
    const char *prefix = "BetterSpellWheel/";
    for (int i = 0; i < entryCount; i++) {
        const Entry *e = &entries[i];
        if (strncmp(e->name, prefix, strlen(prefix))) continue;
        const char *rel = e->name + strlen(prefix);
        if (!strcmp(rel, "config.txt") && keptConfig) { lg(L"kept existing config.txt"); continue; }
        wchar_t relative[260];
        if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, rel, -1, relative, 260))
            return fail(L"Invalid file name in the installer.");
        slashes(relative);
        if (!put(e->name, L.modDir, relative)) return fail(L"Couldn't write the mod files. Check folder permissions and try again.");
    }
    if (!updateModsTxt(L.modsDir, 1)) return fail(L"Couldn't update mods.txt.");
    swprintf(msg, 2048,
        L"BetterSpellWheel %ls is installed.\n\n%ls%ls\n\nGame folder:\n%ls\n\nStart the game and press Q in a world to open BetterSpellWheel.",
        version, ue4ssNote, keptConfig ? L"\nYour existing BetterSpellWheel settings were kept." : L"", game);
    lg(L"done: installed %ls", version);
    box(msg, MB_OK | MB_ICONINFORMATION, 0);
    return 0;
}

static int otherModsPresent(const wchar_t *modsDir)
{
    wchar_t pat[MAX_PATH * 2];
    WIN32_FIND_DATAW fd;
    join(pat, modsDir, L"*");
    HANDLE f = FindFirstFileW(pat, &fd);
    int any = 0;
    if (f == INVALID_HANDLE_VALUE) return 0;
    do {
        if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
        if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L"..") || !_wcsicmp(fd.cFileName, MOD)) continue;
        any = 1;
    } while (!any && FindNextFileW(f, &fd));
    FindClose(f);
    return any;
}

static int uninstall(const wchar_t *game)
{
    Layout L;
    layoutOf(game, &L);
    wchar_t p[MAX_PATH * 2], msg[1024];
    if (validateTarget(&L)) return 1;
    if (isDir(L.modDir)) { removeTree(L.modDir); lg(L"removed %ls", L.modDir); }
    if (!updateModsTxt(L.modsDir, 0)) return fail(L"Could not update mods.txt during uninstall.");
    int removedUe4ss = 0;
    join(p, L.win64, L"ue4ss\\" MARKER);
    if (exists(p) && !otherModsPresent(L.modsDir)) {
        wchar_t ue[MAX_PATH * 2];
        join(ue, L.win64, L"dwmapi.dll"); DeleteFileW(ue);
        join(ue, L.win64, L"ue4ss"); removeTree(ue);
        removedUe4ss = 1;
        lg(L"removed UE4SS (installed by us, no other mods)");
    }
    swprintf(msg, 1024, L"BetterSpellWheel was removed.%ls", removedUe4ss ? L"\nUE4SS was removed too (this installer had added it and no other mods use it)." : L"\nUE4SS and your other mods were left in place.");
    lg(L"done: uninstalled");
    box(msg, MB_OK | MB_ICONINFORMATION, 0);
    return 0;
}

// ------------------------------------------------------------------ main

int WINAPI wWinMain(HINSTANCE hi, HINSTANCE hp, PWSTR cmd, int show)
{
    (void)hi; (void)hp; (void)show;
    int argc = 0;
    wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    wchar_t game[MAX_PATH * 2] = L"";
    int doUninstall = 0, detectOnly = 0;
    for (int i = 1; i < argc; i++) {
        if (!_wcsicmp(argv[i], L"/silent")) silent = 1;
        else if (!_wcsicmp(argv[i], L"/uninstall")) doUninstall = 1;
        else if (!_wcsicmp(argv[i], L"/detect")) detectOnly = 1;
        else if (!_wcsnicmp(argv[i], L"/dir=", 5)) {
            if (wcslen(argv[i] + 5) >= MAX_PATH) return 1;
            wcscpy(game, argv[i] + 5);
        }
    }
    (void)cmd;
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);

    wchar_t logPath[MAX_PATH * 2];
    GetTempPathW(MAX_PATH, logPath);
    wcscat(logPath, L"BetterSpellWheel-install.log");
    logFile = _wfopen(logPath, L"w, ccs=UTF-8");

    if (!loadPayload()) return fail(L"This installer is damaged (its files are missing). Download it again.");
    if (!entry("VERSION") || !entry("BetterSpellWheel/Scripts/main.lua") ||
        !entry("BetterSpellWheel/config.txt") || !entry("BetterSpellWheel/enabled.txt") ||
        !entry("UE4SS.dll") || !entry("UE4SS-settings.ini") || !entry("dwmapi.dll") || !entry("UE4SS-LICENSE.txt"))
        return fail(L"This installer is incomplete. Download it again.");
    const Entry *v = entry("VERSION");
    if (v) { char b[32] = { 0 }; memcpy(b, v->data, v->size < 31 ? v->size : 31); MultiByteToWideChar(CP_UTF8, 0, b, -1, version, 32); }
    lg(L"BetterSpellWheel installer %ls", version);

    if (game[0]) {
        slashes(game);
        size_t n = wcslen(game);
        while (n && (game[n - 1] == L'\\' || game[n - 1] == L'/')) game[--n] = 0;
        if (!isGameDir(game)) return fail(L"The folder given with /dir= doesn't contain RuneScape: Dragonwilds.");
    } else if (!findGame(game) && (silent || !browseForGame(game))) {
        return fail(L"RuneScape: Dragonwilds wasn't found. Install it through Steam, or run the installer again and choose its folder.");
    }
    lg(L"game: %ls", game);
    if (detectOnly) { wchar_t m[1024]; swprintf(m, 1024, L"Game folder: %ls", game); box(m, MB_OK, 0); return 0; }

    while (gameRunning()) {
        if (box(L"RuneScape: Dragonwilds is running. Close the game, then press Retry.", MB_RETRYCANCEL | MB_ICONWARNING, IDCANCEL) != IDRETRY)
            return fail(L"The game is still running, so nothing was changed.");
    }

    Layout L;
    layoutOf(game, &L);
    if (doUninstall) return uninstall(game);
    if (isDir(L.modDir) && !silent) {
        wchar_t m[1024];
        swprintf(m, 1024, L"BetterSpellWheel is already installed.\n\nYes: update to %ls (your settings are kept)\nNo: uninstall BetterSpellWheel\nCancel: do nothing", version);
        int a = box(m, MB_YESNOCANCEL | MB_ICONQUESTION, IDYES);
        if (a == IDNO) return uninstall(game);
        if (a != IDYES) { lg(L"cancelled"); return 0; }
    }
    return install(game);
}
