ASM := nasm
QEMU := qemu-system-x86_64

SRC_DIR := src
BUILD_DIR := build

.PHONY: bootloader always run debug

bootloader: always
	$(MAKE) -C $(SRC_DIR)
	cp $(BUILD_DIR)/boot.bin $(BUILD_DIR)/disk.img
	truncate -s 1440k $(BUILD_DIR)/disk.img

always:
	mkdir -p build

run:
	$(QEMU) -fda $(BUILD_DIR)/disk.img

debug:
	bochs -f bochs.conf