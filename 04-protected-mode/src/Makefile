ASM := nasm

SRC_DIR := .
BUILD_DIR := ../build

.PHONY: bootloader

bootloader:
	$(ASM) -f bin $(SRC_DIR)/main.asm -o $(BUILD_DIR)/boot.bin