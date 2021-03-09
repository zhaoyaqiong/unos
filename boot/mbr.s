%include "boot.inc"
SECTION MBR vstart=0x7c00
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00
    mov ax,0xb800
    mov gs,ax

    mov ax,0600h
    mov bx,0700h
    mov cx,0
    mov dx,148fh

    int 10h
    
    mov byte [gs:0x00],'H' 
    mov byte [gs:0x01],0xA4
    mov byte [gs:0x02],'e'
    mov byte [gs:0x03],0xA4
    mov byte [gs:0x04],'l'
    mov byte [gs:0x05],0xA4
    mov byte [gs:0x06],'l'
    mov byte [gs:0x07],0xA4
    mov byte [gs:0x08],'o'
    mov byte [gs:0x09],0xA4
    mov byte [gs:0x0A],'!'
    mov byte [gs:0x0B],0xA4
    
    mov eax,LOADER_START_SECTOR     ; 起始扇区LBA地址
    mov bx,LOADER_BASE_ADDR         ; 写入的地址
    mov cx,4                        ; 待读入的扇区数
    call rd_disk_m_16               ; 一下读入程序的起始部分（一个扇区）

    jmp LOADER_BASE_ADDR + 0x300

;---
; 功能: 读取硬盘的 n 个扇区
;---
rd_disk_m_16:
                                    ; exa = LBA 扇区号
                                    ; bx = 将数据写入的内存地址
                                    ; cx = 读入的扇区数
    mov esi,eax         ; 备份eax
    mov di,cx           ; 备份cx
; 读写硬盘
; 第一步 设置要读取的扇区数
    mov dx,0x1f2
    mov al,cl
    out dx,al           ; 读取的扇区数
    
    mov eax,esi         ; 恢复ax
; 第二步 将LBA地址存入0x1f3 ~ 0x1f6
    ; LBA 地址 7~0位写入端口0x1f3
    mov dx,0x1f3
    out dx,al

    ; LBA地址 15-8位写入端口0x1f4
    mov cl,8
    shr eax,cl
    mov dx,0x1f4
    out dx,al

    ; LAB地址23-16位写入端口0x1f5
    shr eax,cl
    mov dx,0x1f5
    out dx,al

    shr eax,cl
    and al,0x0f         ; LBA弟24-27位
    or al,0xe0          ; 设置7-4位 位1110,表示lba模式
    mov dx,0x1f6
    out dx,al
; 第三步 将 0x1f7端口写入读命令 0x20
    mov dx,0x1f7
    mov al,0x20
    out dx,al

; 第四步 检测硬盘状态
.not_ready:
    ; 同一端口，写入时表示写入命令字，读取时表示读入硬盘状态
    nop
    in al,dx
    and al,0x88     ; 第4位为1表示硬盘控制器已经准备好数据传输
                    ; 弟七位为1表示硬盘忙
    cmp al,0x08
    jnz .not_ready  ; 如果没准备好继续等
; 第五步 从0x1f0端口读数据
    mov ax,di
    mov dx,256
    mul dx
    mov cx,ax
; di为要读取的扇区数，一个扇区有512个字节，每次读入一个字 需要 di*512/2
; 所以di*256
    mov dx,0x1f0
.go_on_ready:
    in ax,dx
    mov [bx],ax
    add bx,2
    loop .go_on_ready
    ret

    times 510-($-$$) db 0
    db 0x55,0xaa
