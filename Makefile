rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
VHDL_SRC := $(call rwildcard,core,*.vhd)
VHDL_TEST_SRC := $(call rwildcard,test,*.vhd)
VHDL_TEST_BENCHES := $(patsubst test/%.vhd, %, $(VHDL_TEST_SRC))
FMT_SRC := $(patsubst %, fmt-%,$(VHDL_SRC) $(VHDL_TEST_SRC))

test: $(VHDL_TEST_BENCHES)

clean:
	rm -fv **/*~

%_tb: test/%_tb.vhd core/%.vhd
	ghdl -c --std=08 $^ -r $@

ALU := core/alu.vhd \
	core/alu_operations_pkg.vhd

ALU_CONTROL := core/alu_control.vhd \
	core/imm_sx.vhd \
	$(ALU) \
	core/program_counter.vhd \
	core/control_fsm.vhd

alu_tb: test/alu_tb.vhd $(ALU)
	ghdl -c --std=08 $^ -r $@

alu_control_tb: test/alu_control_tb.vhd $(ALU_CONTROL)
	ghdl -c --std=08 $^ -r $@

MEMORY := core/memory.vhd \
	core/mem.vhd \
	core/mbr_sx.vhd \
	core/register_file.vhd

memory_tb: test/memory_tb.vhd $(MEMORY)
	ghdl -c --std=08 $^ -r $@

topmodule_tb: test/topmodule_tb.vhd \
	core/topmodule.vhd \
	$(ALU_CONTROL) $(MEMORY)
	ghdl -c --std=08 $^ -r $@


fmt: $(FMT_SRC)

fmt-core/%.vhd: core/%.vhd
	@echo FORMAT $<
	@emacs -batch $< -f vhdl-beautify-buffer -f save-buffer 2>/dev/null

fmt-test/%.vhd: test/%.vhd
	@echo FORMAT $<
	@emacs -batch $< -f vhdl-beautify-buffer -f save-buffer 2>/dev/null

.PHONY: clean
