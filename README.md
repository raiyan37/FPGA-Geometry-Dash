# FPGA Geometry Dash — Project Overview

This repository contains an FPGA project that renders graphics to a 640×480 VGA display and reads input from a PS/2 keyboard. It includes reusable Verilog modules for VGA timing, pixel memory, keyboard input, and clock generation. The top-level integration is implemented in [`vga_demo.v`](./vga_demo.v).

## Description

The project demonstrates a full video pipeline on Intel/Altera FPGAs. It generates VGA sync signals, manages pixel memory initialized from a `.mif` file, reads PS/2 keyboard scancodes in hardware, and drives a standard VGA monitor using a PLL-derived pixel clock. The Quartus project files are included for synthesis and fitting.

![VGA Demo Preview](./img/demo.gif)

## Techniques Used

### 1. VGA Timing Generation
Implements 640×480 @ 60 Hz VGA timing through hardware counters and sync pulse generation.

MDN reference for display timing concepts:  
https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Basic_animations#understanding_the_canvas_grid

Modules:
- [`vga_controller.v`](./vga_controller.v)
- [`vga_adapter.v`](./vga_adapter.v)
- [`vga_address_translator.v`](./vga_address_translator.v)

### 2. PLL-Based Clock Generation
[`vga_pll.v`](./vga_pll.v) generates the 25.175 MHz pixel clock using Intel’s PLL IP.

### 3. Memory Initialization via MIF
Pixel data is preloaded into on-chip RAM using a Quartus memory initialization file:  
[`background.mif`](./background.mif)

### 4. PS/2 Keyboard Input Hardware
Implements PS/2 protocol including parity handling, serial deserialization, and scancode capture.

Modules:
- [`PS2_Controller.v`](./PS2_Controller.v)
- [`PS2_Demo.v`](./PS2_Demo.v)
- [`Altera_UP_PS2_Data_In.v`](./Altera_UP_PS2_Data_In.v)

Conceptual reference for key input behavior:  
https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent

### 5. Address Translation Hardware
[`vga_address_translator.v`](./vga_address_translator.v) converts 2D pixel coordinates into linear memory addresses for efficient RAM access.

### 6. Full Quartus Project Integration
Includes `.qsf`, `.qpf`, fitter results, timing reports, and database files that illustrate how a complete Quartus project is structured.

## Non-Obvious Technologies and Features

| Technology | Notes |
|-----------|-------|
| Intel/Altera PLL IP | Generates stable video pixel clock. |
| MIF-based RAM initialization | Loads image or frame buffer data at compile time. |
| Low-level PS/2 protocol logic | Hardware-level scancode decoding. |
| VGA bus abstraction | Clean, reusable module interfaces for video output. |
| Quartus project system | Demonstrates device setup, pin assignments, and compilation flow. |

## Project Structure

```text
/
├── vga_demo.v
├── vga_controller.v
├── vga_adapter.v
├── vga_address_translator.v
├── vga_pll.v
├── PS2_Controller.v
├── PS2_Demo.v
├── Altera_UP_PS2_Data_In.v
├── rainbow_640_9.mif
├── vga_demo.qsf
├── vga_demo.qpf
├── output_files/
│   └── (compiled binaries, reports, timing summaries)
├── db/
│   └── (Quartus intermediate build database)
└── img/  (optional future directory)
