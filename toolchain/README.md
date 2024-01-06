# Cross Compiler

## 建置流程

1. 下載 [gcc](http://ftp.tsukuba.wide.ad.jp/software/gcc/releases) 與 [binutils](https://ftp.gnu.org/gnu/binutils)

2. 解壓縮它們

   ```bash
   tar -xf file.tar.gz
   ```

3. 設定環境數

   - 32-bit: i686-elf
   - 64-bit: x86_64-elf

   ```bash
   export PREFIX="$(pwd)/i686-elf"
   export TARGET="i686-elf"
   ```

4. 建立並進入 binutils 的 build 目錄

5. 設定編譯選項並編譯

   ```bash
   ../configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror
   make
   make install
   ```

6. 建立並進入 gcc 的 build 目錄

   ```bash
   ../configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-stage1-languages=c,c++ --without-headers
   make all-gcc
   make all-target-libgcc
   make install-gcc
   make install-target-libgcc
   ```

7. `i686-elf` 中會有 gcc 和 linker
