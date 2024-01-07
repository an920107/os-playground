include ../../Variable.mk

.PHONY: bootloader test

bootloader: test
	$(ASM) boot0.asm -f bin -o $(BUILD_DIR)/boot0.bin
	$(ASM) boot1.asm -f bin -o $(BUILD_DIR)/boot1.bin

test:
	$(XX) -c test.cpp -o $(BUILD_DIR)/test.o $(XX_FLAGS)
