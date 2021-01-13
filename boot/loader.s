%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP    equ     LOADER_BASE_ADDR
jmp loader_start

; 构建gdt
GDT_BASE:           dd  0x00000000
                    dd  0x00000000

CODE_DESC:          dd  0x0000FFFF
                    dd  DESC_CODE_HIGH4

DATA_STACK_DESC:    dd  0x0000FFFF
                    dd  DESC_DATA_HIGH4

VIDEO_DESC:         dd  0x80000007          ; limit=(0xbffff-0xb8000)/4k = 0x7
                    dd  DESC_VIDEO_HIGH4    ; 此时dpl 为0

GDT_SIZE    equ     $ - GDT_BASE
GDT_LIMIT   equ     GDT_SIZE - 1
times 60 dq 0
SELECTOR_CODE   equ (0x0001<<3) + TI_GDT + RPL0 ; 相当于 (CODE_DESC - GDT_BASE) / 8 + TI_GDT + RPL0
SELECTOR_DATA   equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO  equ (0x0003<<3) + TI_GDT + RPL0
; 以下是gdt的指针  前两字节是gdt的界限，后4字节是gdt的起始地址

gdt_ptr     dw      GDT_LIMIT
            dd      GDT_BASE
loadermsg   db      'Loader Boot in real.'

loader_start:


;---
; INT 0x10  功能号 0x13 功能描述：打印字符串
;---
; 输入
; AH 子功能号 13H
; BH 属性（若AL为00H或者01H）
; CX 字符串长度
; (DH,DL) 坐标(行，列)
; ES:BP  字符串地址
; AL 显示输出方式
;   0   字符串只包含显示字符，其显示属性在BL中，显示后 光标位置不变
;   1   字符串只包含显示字符，其显示属性在BL中，显示后 光标位置改变
;   2   字符串包含显示字符和属性，显示后 光标位置不变
;   3   字符串包含显示字符和属性，显示后 光标位置改变
;   无返回值

    mov sp,LOADER_BASE_ADDR
    mov bp,loadermsg            ;   ES:BP   地址串地址
    mov cx,20
    mov ax,0x1301               ;   AH = 13 AL = 01h
    mov bx,0x001f               ;   BH = 0  BL = 1fh 蓝底粉红字
    mov dx,0x0100               ;
    int 0x10

; 准备进入保护模式
; 1 打开A20
; 2 加载GDT
; 3 将cr0的pe位 置1


; 打开A20
    in al,0x92
    or al,0000_0010B
    out 0x92,al

    ; 加载GDT
    lgdt    [gdt_ptr]


; cr0 第0位 置0
    mov eax, cr0
    or eax,0x00000001
    mov cr0,eax

    jmp dword SELECTOR_CODE:p_mode_start


[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs:320], 'E'
    mov byte [gs:322], 'n'
    mov byte [gs:324], 't'
    mov byte [gs:326], 'e'
    mov byte [gs:328], 'r'
    mov byte [gs:330], ' '
    mov byte [gs:332], 'P'
    mov byte [gs:334], 'r'
    mov byte [gs:336], 'o'
    mov byte [gs:338], 't'
    mov byte [gs:340], 'e'
    mov byte [gs:342], 'c'
    mov byte [gs:344], 't'
    mov byte [gs:346], 'e'
    mov byte [gs:348], 'd'
    mov byte [gs:350], ' '
    mov byte [gs:352], 'M'
    mov byte [gs:354], 'o'   
    mov byte [gs:356], 'd'
    mov byte [gs:358], 'e'

    jmp $
