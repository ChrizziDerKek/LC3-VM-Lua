# LC3-VM-Lua
Implementation of the LC-3 virtual machine in lua.

See https://www.jmeiners.com/lc3-vm/ for more details about the LC-3 VM.

See https://github.com/rpendleton/lc3-2048/blob/main/2048.asm for the example program I used.

## This repo includes
- ``lc3vm.lua``: The code for the LC-3 VM written in lua.
- ``lc3vm.luac``: The compiled lua 5.3 code of the VM.
- ``2048.obj``: An example LC-3 assembly file taken from the tutorial above.

## Requirements

While most of the program uses native lua functionalities, there were still some that I had to implement with C callbacks.

Here you can see a list of functions that need to be implemeneted for the program to work:

``bool lc3.checkkey()``
```cpp
static int lc3_checkkey(lua_State* L) {
  HANDLE hstdin = GetStdHandle(STD_INPUT_HANDLE);
  lua_pushboolean(L, WaitForSingleObject(hstdin, 1000) == WAIT_OBJECT_0 && _kbhit());
  return 1;
}
```

``void lc3.flushout()``
```cpp
static int lc3_flushout(lua_State* L) {
  fflush(stdout);
  return 0;
}
```

``void lc3.putc(int)``
```cpp
static int lc3_putc(lua_State* L) {
  if (lua_isinteger(L, 1))
    printf("%c", lua_tointeger(L, 1);
  else
    printf("%c", atoi(luaL_checkstring(L, 1));
  return 0;
}
```

``int lc3.getchar()``
```cpp
static int lc3_getchar(lua_State* L) {
  lua_pushinteger(L, getchar());
  return 1;
}
```

``void lc3.printf(string)``
```cpp
static int lc3_printf(lua_State* L) {
  printf(luaL_checkstring(L, 1));
  return 0;
}
```

``void lc3.setinputbuffering(bool)``
```cpp
static int lc3_setinputbuffering(lua_State* L) {
  HANDLE hstdin = GetStdHandle(STD_INPUT_HANDLE);
  static DWORD oldMode;
  if (L != nullptr && !lua_toboolean(L, 1)) {
    signal(SIGINT, [](int s) {
      lc3_setinputbuffering(nullptr);
      printf("\n");
      exit(-2);
    });
    GetConsoleMode(hstdin, &oldMode);
		SetConsoleMode(hstdin, oldMode ^ ENABLE_ECHO_INPUT ^ ENABLE_LINE_INPUT);
		FlushConsoleInputBuffer(hstdin);
  }
  else SetConsoleMode(hstdin, oldMode);
  return 0;
}
```
