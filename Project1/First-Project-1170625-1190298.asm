# Yousef Hammad - 1170625
# Mohammad AbuJaber - 1190298
# --------------------------------------data-------------------------------------- # 
            .data
mainMenu: .asciiz "\nPlease choose:\ne. Encrypte\nd. Decrypte\nx. Exit\n"
plainFilePrompt: .asciiz "\nPlease input the name of the plain text file\n"
cipherFlePrompt: .asciiz "\nPlease input the name of the cipher text file\n"
shiftAmount: .asciiz "The shift value is: "
fileNamePlain: .space 50 # the Name of the Unencrypted file
fileNameCipher: .space 50 # the Name of the encrypted file
fileNameB: .asciiz "file.file"
rBuffer: .space 64
wBuffer: .space 64
# --------------------------------------text-------------------------------------- # 
      .text
j start
showMainMenu: 
	  # print the Main menu prompt
	  li $v0, 4
	  la $a0, mainMenu
	  syscall
	  # read user selection
	  li $v0, 12
	  syscall
	  beq $v0, 'e', encrypteStart
	  beq $v0, 'd', decrypteStart
	  beq $v0, 'x', exit
	  j showMainMenu
	  # start the encryption window and function
	  encrypteStart:
	  subiu $sp,$sp, 4
	  sw $ra, 0($sp)
	  jal encryptMenu
	  lw $ra, 0($sp)
	  addiu $sp,$sp, 4
	  j showMainMenu
	  
	  # start the decryption window and function
	  decrypteStart:
	  subiu $sp,$sp, 4
	  sw $ra, 0($sp)
	  jal decryptMenu
	  lw $ra, 0($sp)
	  addiu $sp,$sp, 4
	  j showMainMenu
	  
	  exit:
	  jr $ra
# --------------------------------------encryptMenu-------------------------------------- # 
encryptMenu:
	# show the encryption prompt
	li $v0, 4
	la $a0, plainFilePrompt
	syscall
	# read the file name
	li $v0, 8
	la $a0, fileNamePlain
	li $a1, 50
	syscall
	# remove the new line from the name of the file
	la $a0, fileNamePlain # arguiment to the remove new line from input function
	subiu $sp,$sp, 4
	sw $ra, 0($sp)
	jal removeNLFromInput
	lw $ra, 0($sp)
	addiu $sp,$sp, 4
	# open the file in the read flag
	li $v0, 13
	la $a0, fileNamePlain
	li $a1, 0
	li $a2, 0
	syscall
	blt $v0, 0, encryptMenu # if the file doesn't exist ask the user to enter the file name again
	move $t0, $v0
	# open a temp file to write the file without special charachters and in lower case
	li $v0, 13
	la $a0, fileNameB
	li $a1, 1
	li $a2, 0
	syscall
	
	move $a1, $v0 # arguiment 1 of the lowerCase func (the file interpeter for the temp file)
	move $a0, $t0 # arguiment 0 of the lowerCase func (the file interpeter for the Plain file)
	# calling lower case func that removes special characters and turn the alphapet characters to lower case
	subiu $sp,$sp, 4
	sw $ra, 0($sp)
	jal lowerCase
	lw $ra, 0($sp)
	addiu $sp,$sp, 4
	# -------------------------------------
	
	# calling find max word length
	li $v0, 13
	la $a0, fileNameB
	li $a1, 0
	li $a2, 0
	syscall
	move $a0, $v0
	
	subiu $sp,$sp, 4
	sw $ra, 0($sp)
	jal findMaxWordLen
	lw $ra, 0($sp)
	addiu $sp,$sp, 4
	# -------------------------------------
	
	move $t7, $t3 # moving the shift value to register t7 
	rem $t7, $t7, 26 # taking the remainder of the shift value to not make unnecesrly loops around the alphabets
	
	# printing the ui text for the shift amount
	li $v0,4
	la $a0, shiftAmount
	syscall
	# printing the shift value
	li $v0, 1
	move $a0, $t3
	syscall
	# a new line to make the screen readable
	li $v0, 11
	li $a0, '\n'
	syscall
	# printing text to ask the user for a name of the encrypted file
	li $v0,4
	la $a0, cipherFlePrompt
	syscall
	# taking the name of the file from the user
	li $v0, 8
	la $a0, fileNameCipher
	li $a1, 50
	syscall
	
	# remove the new line from the name of the file
	la $a0, fileNameCipher # arguiment 0 of the removeNLFromInput function (the address of the name of the cipher file)
	subiu $sp,$sp, 4
	sw $ra, 0($sp)
	jal removeNLFromInput # remove the new line from the string
	lw $ra, 0($sp)
	addiu $sp,$sp, 4
	
	# opening the temp file for read
	li $v0, 13
	la $a0, fileNameB
	li $a1, 0
	li $a2, 0
	syscall
	move $t8, $v0
	# opening the cipher file for write
	li $v0, 13
	la $a0, fileNameCipher
	li $a1, 1
	li $a2, 0
	syscall
	move $t9, $v0
	# note: theres no need to ask the user again since it will be created if it doesn't exist but in case there isnt enough memory the program will terminate
	bgez $v0, skip111
	jr $ra
	skip111:
	# t0: number of read bytes
	# t1: pointer to read buffer
	# t2: pointer to write buffer
	# t3: value of buffer entry
	cipherL:
		li $v0, 14
		move $a0, $t8
		la $a1, rBuffer
		li $a2, 64
		syscall
		blez $v0, afterCipherL
		move $t0, $v0
		la $t1, rBuffer
		la $t2, wBuffer
		cipherL2:
			beqz $t0, afterCipherL2	 # break condition when the number of bytes to read reaches 0
			subiu $t0, $t0, 1  # decrement the number of bytes
			lb $t3, 0($t1)
			beq $t3, ' ', saveToW  # saving the space as it is
			beq $t3, '\n', saveToW  # saving the new line as it is
			addu $t3, $t3, $t7  # shifting letters by adding the value of $t7 <shift amount>
			ble $t3, 'z', saveToW  # if still in alphabet range it will be saved
			subiu $t3, $t3, 26  # if not, we will subtract 26 to stay in alphabet
			saveToW:
				# storing what in write buffer and then incrementing write and read buffers
				sb $t3, 0($t2)
				addiu $t1, $t1, 1
				addiu $t2, $t2, 1
			j cipherL2
		afterCipherL2:
			# open the file and print the encrypted data
			li $v0, 15
			move $a0, $t9
			la $a1, wBuffer
			subu $a2, $t2, $a1
			syscall
		j cipherL
	
	afterCipherL:
		# closing the files
		li $v0, 16
		move $a0, $t8
		syscall
		li $v0, 16
		move $a0, $t9
		syscall
	
	jr $ra

# --------------------------------------decryptMenu-------------------------------------- # 
decryptMenu:
	# print a text asking the user to enter the name of the cipher file
	li $v0,4
	la $a0, cipherFlePrompt
	syscall
	# taking the input of the user
	li $v0, 8
	la $a0, fileNameCipher
	li $a1, 50
	syscall
	# remove the new line from the name of the file
	la $a0, fileNameCipher
	subiu $sp,$sp, 4
	sw $ra, 0($sp)
	jal removeNLFromInput
	lw $ra, 0($sp)
	addiu $sp,$sp, 4
	
	# open the file in the read flag
	li $v0, 13
	la $a0, fileNameCipher
	li $a1, 0
	li $a2, 0
	syscall
	blt $v0, 0, decryptMenu # if the file doesn't exist ask the user to enter the file name again
	
	move $a0, $v0
	# calculate the number of characters of the longest word
	subiu $sp,$sp, 4
	sw $ra, 0($sp)
	jal findMaxWordLen
	lw $ra, 0($sp)
	addiu $sp,$sp, 4
	
	move $t0, $v0
	
	move $t7, $v0
	rem $t7, $t7, 26
	# printing "The shift value is: "
	li $v0,4
	la $a0, shiftAmount
	syscall
	# printing shift amount
	li $v0, 1
	move $a0, $t0
	syscall
	li $v0, 11
	li $a0, '\n'
	syscall
	
	li $v0, 4
	la $a0, plainFilePrompt
	syscall
	
	li $v0, 8
	la $a0, fileNamePlain
	li $a1, 50
	syscall
	
	la $a0, fileNamePlain
	subiu $sp,$sp, 4
	sw $ra, 0($sp)
	jal removeNLFromInput
	lw $ra, 0($sp)
	addiu $sp,$sp, 4
	
	li $v0, 13
	la $a0, fileNameCipher
	li $a1, 0
	li $a2, 0
	syscall
	move $t8, $v0
	
	li $v0, 13
	la $a0, fileNamePlain
	li $a1, 1
	li $a2, 0
	syscall
	move $t9, $v0
	
	decipherL:
		li $v0, 14
		move $a0, $t8
		la $a1, rBuffer
		li $a2, 64
		syscall
		blez $v0, afterdeCipherL
		move $t0, $v0
		la $t1, rBuffer
		la $t2, wBuffer
		decipherL2:
			beqz $t0, afterdeCipherL2 
			subiu $t0, $t0, 1
			lb $t3, 0($t1)
			# when decryption occurs, spaces and new lines will be saved as they are
			beq $t3, ' ', saveToWd
			beq $t3, '\n', saveToWd
			subu $t3, $t3, $t7  # shifting letters by subtracting the value of $t7 <shift amount>
			bge $t3, 'a', saveToWd  # if still in alphabet range it will be saved
			addiu $t3, $t3, 26  # if not, we will subtract 26 to stay in alphabet
			saveToWd:
				sb $t3, 0($t2)
				addiu $t1, $t1, 1
				addiu $t2, $t2, 1
			j decipherL2
		afterdeCipherL2:
			# writing the new plain file contents
			li $v0, 15
			move $a0, $t9
			la $a1, wBuffer
			subu $a2, $t2, $a1
			syscall
		j decipherL
	
	afterdeCipherL:
		li $v0, 16
		move $a0, $t8
		syscall
		li $v0, 16
		move $a0, $t9
		syscall
	jr $ra
# --------------------------------------removeNLFromInput-------------------------------------- # 
removeNLFromInput:
	li $t0, 50
	move $t1, $a0
	li $t3, 0
	rNLFIL:
		blt $t0, 0, afterrNLFIL
		lb $t2, 0($t1)
		subiu, $t0, $t0, 1
		addiu $t1, $t1, 1
		bne $t2, '\n', rNLFIL
	sb $t3, -1($t1)	
	afterrNLFIL:
	jr $ra
# --------------------------------------lowerCase-------------------------------------- # 
lowerCase:
	move $t0, $a0
	move $t1, $a1
	lowerCaseLoop:
	# $t0: plain file descripter
	# $t1: temp file descripter
	# $t2: the number of bytes read from the plain file
	# $t3: pointer to the rBuffer
	# $t4: pointer to the wBuffer
	# $t5: number of bytes in the wBuffer
	
	li $v0, 14
	move $a0, $t0
	la $a1, rBuffer
	li $a2, 64
	syscall
	blez $v0, afterLowerCaseLoop
	move $t2, $v0
	la $t3, rBuffer
	la $t4, wBuffer
	li $t5, 0
	writingLowerCaseLoop:
		beqz $t2,writeToTempFile
		lb $a0, 0($t3)
		addiu $t3, $t3, 1
		subiu $t2, $t2, 1
		
		subiu $sp, $sp, 4
		sw $ra, 0($sp)
		jal CheckCharacter
		lw $ra, 0($sp)
		addiu $sp, $sp, 4
		
		beq $v0, 0, writingLowerCaseLoop
		sb $v0, 0($t4)
		addiu $t4, $t4, 1
		addiu $t5, $t5, 1
		j writingLowerCaseLoop
	writeToTempFile:	
	li $v0, 15
	move $a0, $t1
	la $a1, wBuffer
	move $a2, $t5
	syscall
	j lowerCaseLoop
	
	afterLowerCaseLoop:
	li $v0, 16
	move $a0, $t0
	syscall
	li $v0, 16
	move $a0, $t1
	syscall
	
	jr $ra
# --------------------------------------findMaxWordLen-------------------------------------- # 
findMaxWordLen:
	# t0: file descripter of temp file
	# t1: number of bytes read from temp file
	# t2: counter
	# t3: max
	# t4: pointer to rBuffer
	move $t0, $a0
	li $t2, 0
	li $t3, -1  # giving -1 as an initial value for max number of letters
	countMaxWord: 
		li $v0, 14
		move $a0, $t0
		la $a1, rBuffer
		li $a2, 64
		syscall
		# the number of characters read will be returned in $v0
		blez $v0, afterCountMaxWord  # if done reading then close the file and return the value
		move $t1, $v0
		la $t4, rBuffer
		goOverBuffer:
			beqz $t1, countMaxWord
			lb $t5, 0($t4)
			# incrementing the pointer and decrementing the number of bytes read
			addiu $t4, $t4, 1
			subiu $t1, $t1, 1
			# the counter will be reset when moving to new word/line
			beq $t5, ' ', resetCounter
			beq $t5, '\n', resetCounter
			addiu $t2, $t2, 1
			ble $t2, $t3, goOverBuffer 
			move $t3, $t2
			j goOverBuffer
			resetCounter:
			li $t2, 0
		j goOverBuffer
	
	afterCountMaxWord:

	li $v0, 16
	move $a0, $t0
	syscall
	
	move $v0, $t3
	
	jr $ra
# --------------------------------------CheckCharacter-------------------------------------- # 
CheckCharacter:
	# neglecting spacing, new lines and small letters
	bne $a0, ' ', afterSpace
	move $v0, $a0
	jr $ra
	afterSpace:
	bne $a0, '\n', afterNL 
	li $v0, '\n'
	jr $ra
	afterNL:
	blt $a0, 'a', checkCapital
	bgt $a0, 'z', checkCapital
	move $v0, $a0
	jr $ra
	checkCapital:
		# checking whether the character is an alphabet or not
		blt $a0, 'A', returnNull
		bgt $a0, 'Z', returnNull
		# if it was alphabet, add 32 to convert to lower case
		addiu $a0, $a0, 32
		move $v0, $a0
		jr $ra
	returnNull:
	# if it wasn't alphabet, return null to remove it
	li $a0, 0
	move $v0, $a0
	jr $ra
# --------------------------------------start-------------------------------------- # 
start:
jal showMainMenu

li $v0, 10
syscall
