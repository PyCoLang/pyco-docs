# PyCo Documentation

**PyCo** is a Python-like language for low-level programming that combines the readability of Python with the efficiency of machine-level code.

## Key Features

- **Python-like syntax** - Clean, readable code with indentation-based blocks
- **Strict typing** - Static types with compile-time validation (Pascal influence)
- **Low-level control** - Direct memory access, bit operations (C influence)
- **Memory-mapped variables** - Typed access to hardware registers (`var: byte[0xD020]`)
- **Alias type** - Dynamic typed references with runtime address assignment
- **Platform-independent** - Different compiler backends for various targets
- **Target platforms** - 8/16/32-bit systems, microcontrollers

The first reference implementation targets the Commodore 64.

## Language Reference

Full documentation of the PyCo language:

- [Language Reference](language-reference/)
- [Quick Reference](language-reference/README.md) - Types, syntax, operators, key differences from Python

## C64 Implementation

- [C64 Backend Reference](implementations/C64/)

## Other Resources

- [Built-in 6502 Assembler](assembler/)
- [VICE Debugger Integration](vice/)
