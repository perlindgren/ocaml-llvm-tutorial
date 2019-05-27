SRC_DIR:=src

TOOLS:=tutorial05

TARGET:=native
#TARGET:=byte

LLVM_VERSION := 8.0
CLANG := clang
LLC := llc

#OCAMLBUILDFLAGS:=-r -classic-display -j 0 -cflags -w,@a-4
OCAMLBUILDFLAGS:=-r -classic-display -j 0 

export OCAMLPATH=/usr/lib/ocaml/llvm

tutorial05_OCAMLBUILDFLAGS:=-use-ocamlfind -pkgs llvm,llvm.analysis,llvm.bitwriter,llvm.target,llvm_X86 -lflags -ccopt,-L/usr/lib/llvm-$(LLVM_VERSION)/lib

################
OCAMLBUILD:=ocamlbuild

CLEAN_RULES:=$(patsubst %,%-clean,$(TOOLS))

.PHONY: $(TOOLS) clean $(CLEAN_RULES) default run

default: $(TOOLS)

$(TOOLS):
	$(OCAMLBUILD) $(OCAMLBUILDFLAGS) $($@_OCAMLBUILDFLAGS) $($@_OCAMLBUILDFLAGS_$(TARGET)) -I $(SRC_DIR) -build-dir build/$@ $@.$(TARGET)

clean: $(CLEAN_RULES)
	-rm -f hello hello.o hello.s hello.bc

$(CLEAN_RULES):
	$(OCAMLBUILD) $(OCAMLBUILDFLAGS) -I $(SRC_DIR) -build-dir build/$(patsubst %-clean,%,$@) -clean $(patsubst %-clean,%,$@).$(TARGET)

run: $(TOOLS) hello
	./hello

hello: hello.o
	$(CLANG) -o $@ $<

hello.o: hello.s
	$(CLANG) -c hello.s

hello.s: hello.bc
	$(LLC) -relocation-model=pic $<

hello.bc: $(TOOLS)
	./build/tutorial05/src/tutorial05.native $@
