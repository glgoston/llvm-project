/* Default linker script for Infineon TC27x TriCore microcontrollers
 * 
 * TC27x Family Memory Map:
 * - Program Flash (PFLASH): 4MB at 0x80000000 (cached) / 0xA0000000 (uncached)
 * - Data Flash (DFLASH):    384KB at 0xAF000000
 * - Program Scratchpad (PSPR): 64KB at 0xC0000000 (local RAM, fast)
 * - Data Scratchpad (DSPR):   240KB at 0xD0000000 (local RAM, fast)
 * - LMU SRAM:                  32KB at 0xB0000000 (shared RAM)
 * 
 * This linker script can be customized for specific TC27x derivatives.
 * Use with: ld.lld -T tricore-tc27x.lds input.o -o output.elf
 */

ENTRY(_start)

MEMORY
{
  /* Program Flash - Cached access (default for code execution) */
  PFLASH (rx)   : ORIGIN = 0x80000000, LENGTH = 4M

  /* Program Flash - Uncached access (for const data if needed) */
  PFLASH_NC (rx): ORIGIN = 0xA0000000, LENGTH = 4M

  /* Data Flash - Non-volatile data storage */
  DFLASH (r)    : ORIGIN = 0xAF000000, LENGTH = 384K

  /* Program Scratchpad - Fast local RAM for time-critical code */
  PSPR (rwx)    : ORIGIN = 0xC0000000, LENGTH = 64K

  /* Data Scratchpad - Fast local RAM for frequently accessed data */
  DSPR (rw)     : ORIGIN = 0xD0000000, LENGTH = 240K

  /* LMU SRAM - Shared memory accessible by all CPUs */
  LMU_SRAM (rw) : ORIGIN = 0xB0000000, LENGTH = 32K
}

SECTIONS
{
  /* Reset vector and startup code in PFLASH */
  .startup : ALIGN(4)
  {
    KEEP(*(.startup))
    KEEP(*(.reset))
  } > PFLASH

  /* Optional: Fast code section in PSPR for critical functions */
  .text_pspr : ALIGN(4)
  {
    *(.text.fast)
    *(.text.pspr)
  } > PSPR AT> PFLASH

  /* Optional: Shared data in LMU SRAM (multi-core access) */
  .shared : ALIGN(4)
  {
    *(.shared)
    *(.lmu_data)
  } > LMU_SRAM

  /* Non-volatile data in DFLASH */
  .nvdata : ALIGN(4)
  {
    *(.nvdata)
    *(.dflash)
  } > DFLASH

  /* Program code in PFLASH (cached) */
  .text : ALIGN(4)
  {
    *(.text .text.*)
    *(.gnu.linkonce.t.*)
    . = ALIGN(4);
    _etext = .;
  } > PFLASH

  /* Read-only data in PFLASH */
  .rodata : ALIGN(4)
  {
    *(.rodata .rodata.*)
    *(.gnu.linkonce.r.*)
    . = ALIGN(4);
  } > PFLASH

  /* Constructor/destructor tables */
  .ctors : ALIGN(4)
  {
    KEEP(*(.ctors))
    KEEP(*(.init_array))
  } > PFLASH

  .dtors : ALIGN(4)
  {
    KEEP(*(.dtors))
    KEEP(*(.fini_array))
  } > PFLASH

  /* Initialized data - Load address in PFLASH, VMA in DSPR */
  .data : ALIGN(4)
  {
    _data_start = .;
    *(.data .data.*)
    *(.gnu.linkonce.d.*)
    . = ALIGN(4);
    _data_end = .;
  } > DSPR AT> PFLASH

  _data_load_start = LOADADDR(.data);

  /* Small data area for efficient access (TriCore small-data model) */
  .sdata : ALIGN(4)
  {
    _sdata_start = .;
    *(.sdata .sdata.*)
    *(.gnu.linkonce.s.*)
    . = ALIGN(4);
    _sdata_end = .;
  } > DSPR AT> PFLASH

  /* Uninitialized data in DSPR */
  .bss (NOLOAD) : ALIGN(4)
  {
    _bss_start = .;
    *(.bss .bss.*)
    *(.gnu.linkonce.b.*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > DSPR

  /* Small BSS for efficient access */
  .sbss (NOLOAD) : ALIGN(4)
  {
    _sbss_start = .;
    *(.sbss .sbss.*)
    *(.gnu.linkonce.sb.*)
    . = ALIGN(4);
    _sbss_end = .;
  } > DSPR

  /* Stack in DSPR (grows downward) */
  .stack (NOLOAD) : ALIGN(8)
  {
    . = . + 16K;  /* 16KB stack */
    _stack_top = .;
  } > DSPR

  /* Heap in remaining DSPR space */
  .heap (NOLOAD) : ALIGN(4)
  {
    _heap_start = .;
    . = ORIGIN(DSPR) + LENGTH(DSPR) - 1;
    _heap_end = .;
  } > DSPR

  /* Debug sections (not loaded to target) */
  .debug_info     0 : { *(.debug_info) }
  .debug_abbrev   0 : { *(.debug_abbrev) }
  .debug_line     0 : { *(.debug_line) }
  .debug_frame    0 : { *(.debug_frame) }
  .debug_str      0 : { *(.debug_str) }
  .debug_loc      0 : { *(.debug_loc) }
  .debug_ranges   0 : { *(.debug_ranges) }

  /* Discard unwanted sections */
  /DISCARD/ :
  {
    *(.comment)
    *(.note)
  }
}
