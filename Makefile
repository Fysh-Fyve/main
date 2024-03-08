rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) \
	  $(filter $(subst *,%,$2),$d))

RTL_DIR := rtl
SRC_DIR := $(RTL_DIR)/core
TEST_DIR := $(RTL_DIR)/test

VHDL_SRC := $(call rwildcard,$(SRC_DIR),*.vhd)
VHDL_TEST_SRC := $(call rwildcard,$(TEST_DIR),*.vhd)
VHDL_TEST_BENCHES := $(patsubst $(TEST_DIR)/%.vhd, %, $(VHDL_TEST_SRC))

ASM_SRC := $(call rwildcard,asm,*.s)
ASM_HEX := $(patsubst %.s,%.hex,$(ASM_SRC))

FMT_SRC := $(patsubst %, fmt-%,$(VHDL_SRC) $(VHDL_TEST_SRC))

export GHDL_FLAGS := compile --std=08
# GHDL_FLAGS += -frelaxed
# If you wanna silence annoying errors
export RUN_FLAGS := --ieee-asserts=disable
ifdef WAVE
RUN_FLAGS += --wave=wave.ghw
endif
# export RUN_FLAGS := --assert-level=warning # If you wanna be super strict

test: $(VHDL_TEST_BENCHES)

wave:
	WAVE=1 $(MAKE) topmodule_tb

clean:
	rm -fv **/*~ $(ASM_HEX)

hex: $(ASM_HEX)

rom: rtl/core/rom_pkg.vhd

rtl/core/rom_pkg.vhd: asm/example.hex \
	build/fyve-rom \
	scripts/rom/rom_pkg.part1.vhd \
	scripts/rom/rom_pkg.part2.vhd
	./scripts/make_rom.sh $^

PREFIX=riscv-none-elf

%.dump: asm/%.hex
	$(PREFIX)-objdump -D -b binary -m riscv $<

%.dump: sw/%.hex
	$(PREFIX)-objdump -D -b binary -m riscv $<

%.rom: asm/%.hex
	./scripts/make_rom.sh $<

%.hex: %.elf
	$(PREFIX)-objcopy -O binary $< $@

%.elf: sw/fysh-fyve.ld sw/boot.o sw/gpio.o %.o
	$(PREFIX)-gcc -march=rv32i -nostdlib -T $^ -o $@

%.o: %.c
	$(PREFIX)-gcc -c $< -mabi=ilp32 -O3 -march=rv32i -o $@

%.s: %.c
	$(PREFIX)-gcc -S $< -mabi=ilp32 -O3 -march=rv32i -o $@

%.o: %.s
	$(PREFIX)-as $< -march=rv32i -o $@

build/fyve-%: scripts/%.cc
	cd build && cmake ../scripts && make


%_tb: $(TEST_DIR)/%_tb.vhd $(SRC_DIR)/%.vhd
	@TB="$@" ./scripts/run_test.sh $^

_CONTROLLER := control_fsm \
	       fysh_fyve_pkg \

CONTROLLER := $(patsubst %, $(SRC_DIR)/%.vhd, $(_CONTROLLER))

control_fsm_tb: $(TEST_DIR)/control_fsm_tb.vhd $(CONTROLLER)
	@TB="$@" ./scripts/run_test.sh $^

_ALU := alu \
	fysh_fyve_pkg \

ALU := $(patsubst %, $(SRC_DIR)/%.vhd, $(_ALU))

_ALU_CONTROL := imm_sx \
		program_counter \
		control_fsm \
		clk_divider \

ALU_CONTROL := $(patsubst %, $(SRC_DIR)/%.vhd, $(_ALU_CONTROL)) \
	$(ALU) \

alu_tb: $(TEST_DIR)/alu_tb.vhd $(ALU)
	@TB="$@" ./scripts/run_test.sh $^


_MEM := mem \
	brom \
	bram \
	rom_pkg \
	fysh_fyve_pkg \

MEM := $(patsubst %, $(SRC_DIR)/%.vhd, $(_MEM))

mem_tb: $(TEST_DIR)/mem_tb.vhd $(MEM)
	@TB="$@" ./scripts/run_test.sh $^

_MEMORY := $(_MEM) \
	   phy_map \
	   gpio_pins \
	   mbr_sx \
	   register_file \
	   grilled_fysh \

MEMORY := $(patsubst %, $(SRC_DIR)/%.vhd, $(_MEMORY))

topmodule_tb: $(TEST_DIR)/topmodule_tb.vhd \
	$(SRC_DIR)/topmodule.vhd \
	$(ALU_CONTROL) $(MEMORY)
	@TB="$@" ./scripts/run_test.sh $^

fmt: $(FMT_SRC)

fmt-$(RTL_DIR)/%.vhd: $(RTL_DIR)/%.vhd
	@echo FORMAT $<
	@emacs -batch $< -f vhdl-beautify-buffer -f save-buffer 2>/dev/null

VIVADO_PROJECT_DIR := proj
VIVADO_PROJECT_NAME := fysh-fyve
VIVADO_PROJECT_FILE := $(VIVADO_PROJECT_DIR)/$(VIVADO_PROJECT_NAME).xpr

tcl: $(VIVADO_PROJECT_FILE)
	vivado -mode tcl $<

$(VIVADO_PROJECT_FILE):
	vivado -mode batch -source fysh-fyve.tcl

clean-project:
	rm -rf $(VIVADO_PROJECT_DIR)

.PHONY: clean fmt test tcl clean-project rom hex
