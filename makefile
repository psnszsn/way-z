run:
	zig build run

val: 
	zig build -fstage1 -Dcpu=baseline
	valgrind --leak-check=full --track-origins=yes --show-leak-kinds=all --num-callers=15 -s zig-out/bin/zoinx
	# valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes -s zig-out/bin/zoinx
