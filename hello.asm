	#&print_ch_name ECALLi 0 WRWi &print_ch
	#&message NOP CALLi &print_str
	HALT

@print_str
	DUP RDB DUP JZi &done
	RDWi &print_ch ECALL
	ADDi 1
	JMPi &print_str
@done RET


[data]
	@print_ch_name 8 "print_ch"
	@print_ch [resw]
	@message "Hello, world!" 10 0
