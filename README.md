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

## Project Status

| Component              | Status                                      |
| ---------------------- | ------------------------------------------- |
| Language specification | Mostly complete, still evolving             |
| C64 compiler           | Coming soon (Apache 2.0 license)            |

**Proof of concept:** [SLOTSHOT](https://github.com/PyCoLang/slotshot) - a full C64 game written entirely in PyCo.

This documentation describes the PyCo language design. The specification is close to final, but some features may still change as the compiler development reveals edge cases or better solutions.

Feedback and suggestions are welcome!

## Language Reference

Full documentation of the PyCo language:

- [Language Reference](language-reference/)
- [Quick Reference](language-reference/README.md) - Types, syntax, operators, key differences from Python

## C64 Implementation

- [C64 Backend Reference](implementations/C64/)

## Other Resources

- [Built-in 6502 Assembler](assembler/)
