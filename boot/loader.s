%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP    equ     LOADER_BASE_ADDR
; jmp loader_start
; 在主引导mbr.s中，直接跳转到0x900+300跳过定义的数据区
; 因为jmp loader_start机器码占用3字节，在他之后定义的数据，地址未定义到偶数，影响执行效率
; 将来对total_mem_bytes引用时，也要用到奇数地址，很别扭

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

; dq填充8字节，dw填充2字节，dd填充4字节
; 因代码加载至0x900, 上面的代码已填充dd*8+dq*60共计512字节(0x200)，所以该处地址为0xb00
; total_mem_bytes用于保存内存容量，以字节为单位
total_mem_bytes dd  0

; equ 不分配内存地址
SELECTOR_CODE   equ (0x0001<<3) + TI_GDT + RPL0 ; 相当于 (CODE_DESC - GDT_BASE) / 8 + TI_GDT + RPL0
SELECTOR_DATA   equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO  equ (0x0003<<3) + TI_GDT + RPL0



; 以下是gdt的指针  前两字节是gdt的界限，后4字节是gdt的起始地址

gdt_ptr     dw      GDT_LIMIT
            dd      GDT_BASE

; 人工对齐:total_mem_bytes4 + gdt_ptr6 + ards_buf244 + ards_nr2，共256字节
ards_buf times 244 db 0
ards_nr dw  0   ; 用于记录ARDS结构体数量

loadermsg   db      'Loader Boot in real.'

loader_start:

; int15h eax=0000E820h , edx= 534D4150h('SMAP') 获取内存布局
	xor ebx, ebx            ; 第一次使用，ebx的值要为0
	mov edx, 0x534D4150     ; edx只赋值一次
	mov di, ards_buf        ; ards结构缓冲区
.e820_mem_get_loop:
    mov eax, 0x0000e820 ; 每次执行int15后，eax的值会变为534D4150h，所以每次执行前都需要更新子功能号
    mov ecx, 20         ; ards地址范围描述符大小是20个字节
    int 0x15
    jc .e820_failed_so_try_e801 ; 如果cf位为1则有错误发生，尝试0x801子功能
    add di, cx          ; 使di增加20字节指向缓冲区中新的ARDS结构位置
    inc word [ards_nr]  ; 记录ards数量
    cmp ebx, 0          ; 若ebx为0且cf不为1，这说明ards全部返回
                        ; 当前已是最后一个
    jnz .e820_mem_get_loop

; 在所有ards结构中，找到最大的可用内存(base_add_low + length_low)，即内存容量
    mov cx, [ards_nr]   ; 遍历每一个ards结构体，循环次数是ards的数量
    mov ebx, ards_buf
    xor edx, edx        ; 保存最大的内存容量，这里先清0

.find_max_mem_area:
    mov eax, [ebx]
    add eax, [ebx + 8]
    add ebx, 20
    cmp edx, eax
    jge .next_ards
    mov edx, eax
.next_ards:
    loop .find_max_mem_area
    jmp mem_get_ok

.e820_failed_so_try_e801:
; int15h ax=E801h获取内存大小，最大支持4G
; 返回后,axcx值一样,以KB为单位，bxdx值一样，以64KB为单位
; 在ax和cx寄存器中为低16MB，在bx和dx寄存器中为16MB到4GB
    mov ax, 0xe801
    int 0x15
    jc .e801_failed_so_try88

; 1先算出低15MB的内存
; ax和cx中是以KB为单位的内存数量，将其转换为以byte为单位
    mov cx, 0x400       ; cx和ax值一样，cx用作乘数
    mul cx
    shl edx,16
    and eax, 0x0000FFFF
    or edx, eax
    add edx, 0x100000   ; ax只是15MB，故要加1MB
    mov esi, edx        ; 先把低15MB的内存容量存入esi寄存器备份
; 2再将16MB以上的内存转换为byte为单位
; 寄存器bx和dx中是以64KB为单位的内存数量
    xor eax, eax
    mov ax, bx
    mov ecx, 0x10000    ; 0x10000十进制为64KB
    mul ecx             ; 32位乘法，默认的被乘数是eax，积为64位
                        ; 高32位存入edx，低32位存入eax
    add esi, eax        ; 由于此方法只能测出4GB以内的内存，故32位eax足够了
; edx肯定为0，只加eax便可
    mov edx, esi        ;edx为总内存大小
    jmp mem_get_ok


.e801_failed_so_try88:
; int15h ah=0x88获取内存大小，只能获取64MB之内
    mov ah, 0x88
    int 0x15
    jc .error_hlt
    and eax, 0x0000FFFF

    ; 16位乘法，被乘数是ax, 积位32位，积的高16位在dx中
    mov cx, 0x400       ; 0x400等于1024，将ax中的内存容量换为以byte为单位
    mul cx
    shl edx, 16         ; 把dx移到高16位
    or edx, eax         ; 把积的低16位组合到edx，为32位积
    add edx, 0x100000   ; 0x88子功能只会返回1MB以上的内存，故实际内存需要加上1MB
    jmp mem_get_ok

.error_hlt:
	mem_get_error_msg   db      'Get Memeory Error.'
	; 打印错误信息
	mov sp,LOADER_BASE_ADDR
    mov bp,mem_get_error_msg    ;   ES:BP   地址串地址
    mov cx,20
    mov ax,0x1301               ;   AH = 13 AL = 01h
    mov bx,0x001f               ;   BH = 0  BL = 1fh 蓝底粉红字
    mov dx,0x0100               ;
    int 0x10
    jmp $

mem_get_ok:
    mov [total_mem_bytes], edx

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
