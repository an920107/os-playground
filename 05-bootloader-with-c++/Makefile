include Variable.mk

.PHONY: floppy bootloader kernel always run debug


# Build

floppy: bootloader
	dd if=/dev/zero of=$(BUILD_DIR)/floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "SQUIIIOS" $(BUILD_DIR)/floppy.img
	dd if=$(BUILD_DIR)/boot0.bin of=$(BUILD_DIR)/floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/floppy.img $(BUILD_DIR)/boot1.bin "::boot1.bin"

bootloader: always
	$(MAKE) -C $(SRC_DIR)/bootloader \
		TOOLCHAIN=$(abspath $(TOOLCHAIN)) \
		BUILD_DIR=$(abspath $(BUILD_DIR))

always:
	export PATH=$(PATH):$(TOOLCHAIN)/bin
	mkdir -p $(BUILD_DIR)


# Utils

run:
	$(QEMU) -fda $(BUILD_DIR)/floppy.img

debug:
	bochs -f bochs.conf
