ASM := nasm
QEMU := qemu-system-x86_64

CC = $(TOOLCHAIN)/bin/i686-elf-gcc
XX = $(TOOLCHAIN)/bin/i686-elf-g++
XX_FLAGS = -ffreestanding -O2 -Wall -Wextra -fno-exceptions -fno-rtti

PWD := $(shell pwd)

TOOLCHAIN := $(PWD)/../toolchain/i686-elf
SRC_DIR := $(PWD)/src
BUILD_DIR := $(PWD)/build