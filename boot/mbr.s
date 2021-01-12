; 主引导程序
; ------------------------------------------------------------
SECTION MBR vstart=0x7c00
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov sp, 0x7c00
	mov ax, 0xb800
	mov gs, ax

; 利用0x06功能，上卷全部行，进行清屏
; INT 0x10 功能号：0x06 功能描述：上卷窗口
; 输入：
; AH 功能号 0x06
; AL 上卷行数 0为全部
; (CL, CH) 窗口左上角(x, y)位置
; (DL, DH) 窗口右下角(x, y)位置
; 无返回值
; ------------------------------------------------------------
	mov ax, 0x600
	mov bx, 0x700
	mov cx, 0x0 		; 左上角(0, 0)
	mov dx, 0x184f 		; 右下角(80, 25)
	; VGA 模式下一行只能容纳80个字符 共25行
	int 0x10


	mov byte [gs: 0x00], 'U'
	mov byte [gs: 0x01], 0xA4 	; A表示绿色背景闪烁，4表示前景色红色


	mov byte [gs: 0x02], 'N'
	mov byte [gs: 0x03], 0xA4

	mov byte [gs: 0x04], 'O'	
	mov byte [gs: 0x05], 0xA4

	mov byte [gs: 0x06], 'S'
	mov byte [gs: 0x07], 0xA4



	jmp $ 					; 使程序死循环

	message db "Outis"
	times 510 - ($-$$) db 0
	db 0x55, 0xaa











