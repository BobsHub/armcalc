.data
intro:     .ascii "Welcome to your friendly calculator.\n"
           .asciz "Enter an expression, or an empty line to quit\n"
output:    .asciz "\t= %f\n\n"
error_msg: .asciz "Invalid expression!\n"

dbl_zero: .double 0.0
dbl_one:  .double 1.0
dbl_ten:  .double 10.0

.equ	BUFFLEN, 40	@ Maximum length for input string
.equ	DELIMIT, 10	@ Charater that delimits the string
.equ	EXIT_NORMAL, 0
.equ	EXIT_ERROR, 1

buffer: .skip BUFFLEN	@ Allocate space for input string
addr_char: .word 0	@ Points to a character in the string

.text
.global main

main:
	str		lr, [sp, #-8]!
	ldr		r0, =intro	@ Print intro message
	bl		printf
expression:
	ldr		r0, =buffer	@ Get expression string from console
	mov		r1, #BUFFLEN
	ldr		r2, =stdin
	ldr		r2, [r2]
	bl		fgets

	ldr		r1, =addr_char	@ Save start of buffer in addr_char
	str		r0, [r1]

	ldrb		r0, [r0]	@ Empty line exits program
	teq		r0, #DELIMIT
	beq		end 

	bl		eatspaces	@ Remove spaces in expression
	bl		expr		@ Evaluate expression	

	vmov.f64	r2, r3, d0	@ Print the expression value
	ldr		r0, =output
	bl		printf
	b		expression	
end:
	mov 		r0, #EXIT_NORMAL
	ldr 		lr, [sp], #+8
	bx 		lr

@ Function to remove spaces in the expression buffer
eatspaces:
	str		lr, [sp, #-8]!
	ldr		r0, =buffer	@ r0 points to source character
	ldr		r1, =buffer	@ r1 points to destination charater
copy_char:
	ldrb		r2, [r1]
	teq		r2, #DELIMIT	@ When we reach end of string
	beq		copy_done	@ stop copying
	ldrb		r2, [r0]	
	teq		r2, #32		@ If space encountered in source
	addeq		r0, r0, #1	@ point to next character in source
	beq		copy_char
	strb		r2, [r1]	@ Otherwise copy souce char to dest char
	add		r0, r0, #1	@ Point to next character in souce
	add		r1, r1, #1	@ and dest
	b		copy_char	
copy_done:
	ldr 		lr, [sp], #+8
	bx		lr

@ Function to recognize a number in a string, or an expression in parentheses
number:
	str		lr, [sp, #-8]!
	
	ldr		r0, =addr_char
	ldr		r0, [r0]
	ldrb		r1, [r0]
	teq		r1, #40		@ '(' found
	bne		number_start
	add		r0, r0, #1	@ Increment pointer to start of sub expression
	ldr		r1, =addr_char	
	strb		r0, [r1]	
	bl		expr		@ Evaluate number within parentheses
	b		number_done
number_start:
	ldr		r1, =dbl_zero
	vldr		d0, [r1]	@ d0 to store final value of number
number_intpart:
	ldrb		r1, [r0]	
	cmp		r1, #48		@ When non-digit detected
	blt		number_int_done @ done evaluating integer part of number 
	cmp		r1, #57		
	bgt		number_int_done
	sub		r1, r1, #48	@ Evaluate integer part
	vmov.u32	s2, r1
	vcvt.f64.u32	d1, s2
	ldr		r1, =dbl_ten
	vldr		d2, [r1]
	vmul.f64	d0, d0, d2
	vadd.f64	d0, d0, d1	
	add		r0, r0, #1
	b		number_intpart
number_int_done:
	teq		r1, #46		@ '.' found ?
	bne		number_done	@ if not our number is only an integer
	
	ldr		r1, =dbl_one
	vldr		d1, [r1]	@ If we reach here factor for decimal places
number_fracpart:
	add		r0, r0, #1
	ldrb		r1, [r0]
	cmp		r1, #48		@ When non-digit detected
	blt		number_done	@ done evaluating fractional part of number
	cmp		r1, #57
	bgt		number_done
	ldr		r2, =dbl_ten
	vldr		d2, [r2]
	vdiv.f64	d1, d1, d2
	sub		r1, r1, #48
	vmov.u32	s4, r1
	vcvt.f64.u32	d2, s4
	vmul.f64	d2, d2, d1
	vadd.f64	d0, d0, d2
	b		number_fracpart			
number_done:
	ldr		r1, =addr_char	@ Save current string pointer
	str		r0, [r1]	
	ldr		lr, [sp], #+8
	bx		lr

@ Function to get the value of a term
term:
	str		lr, [sp, #-8]!
	bl		number		@ Get the first number in the term, in d0
term_mul:
	ldr		r0, =addr_char
	ldr		r0, [r0]	@ String pointer in r0
	ldrb		r1, [r0]	
	teq		r1, #42		@ '*' detected ?
	bne		term_div
	add		r0, r0, #1	@ Advance pointer to next character
	ldr		r1, =addr_char	
	str		r0, [r1]
	vmov.f64	r0, r1, d0	@ Save the first number
	stmdb		sp!, {r0, r1}
	bl		number		@ Get the next number
	ldmia		sp!, {r0, r1}
	vmov.f64	d1, r0, r1
	vmul.f64	d0, d0, d1	@ Multiply the next number in the term
	b		term_mul			
term_div:
	teq		r1, #47		@ '/' detected  ?
	bne		term_done
	add		r0, r0, #1	@ Advance pointer to next character
	ldr		r1, =addr_char
	str		r0, [r1]
	vmov.f64	r0, r1, d0	@ Save the first number
	stmdb		sp!, {r0, r1}
	bl		number		@ Get the second number
	ldmia		sp!, {r0, r1}
	vmov.f64	d1, r0, r1
	vdiv.f64	d0, d1, d0	@ Divide the first by the second number
	b		term_mul		
term_done:
	ldr		lr, [sp], #+8
	bx		lr

@ Function to evaluate an arithmetic expression
expr:
	str		lr, [sp, #-8]!
	bl		term		@ Get first term in d0
expr_loop:
	ldr		r0, =addr_char
	ldr		r0, [r0]	@ String pointer in r0
	ldrb		r1, [r0]
	teq		r1, #DELIMIT	@ If we've reached end of expression
	beq		expr_done	@ return our final value in d0
	teq		r1, #41		@ ')' detected
	beq		expr_done	@ return sub expression () in d0	
expr_add:
	teq		r1, #43		@ '+' detected ?
	bne		expr_sub
	add		r0, r0, #1	@ Advance pointer to next character
	ldr		r1, =addr_char
	str		r0, [r1]
	vmov.f64	r0, r1, d0	@ Save the first term
	stmdb		sp!, {r0, r1}
	bl		term		@ Get the next term
	ldmia		sp!, {r0, r1}
	vmov.f64	d1, r0, r1
	vadd.f64	d0, d0, d1	@ Add the next term to d0
	b		expr_loop
expr_sub:	
	teq		r1, #45		@ '-' detected
	bne		expr_invalid
	add		r0, r0, #1	@ Advance pointer to next character
	ldr		r1, =addr_char
	str		r0, [r1]
	vmov.f64	r0, r1, d0	@ Save the first term
	stmdb		sp!, {r0, r1}
	bl		term		@ Get the next term
	ldmia		sp!, {r0, r1}
	vmov.f64	d1, r0, r1
	vsub.f64	d0, d1, d0	@ Subtract the second term from the first
	b		expr_loop
expr_invalid:				@ If we reach here the string is junk
	ldr		r0, =error_msg
	bl		printf
	mov		r0, #EXIT_ERROR
	mov		r7, #1
	swi		0
expr_done:
	add		r0, r0, #1
	ldr		r1, =addr_char
	str		r0, [r1]
	ldr		lr, [sp], #+8
	bx		lr	
