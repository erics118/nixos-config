bin/symbol_image: symbol_image.m | bin
	clang -std=c99 -O3 -fobjc-arc -framework AppKit $< -o $@

bin:
	mkdir bin
