bin/menus: menus.m | bin
	clang -std=c99 -O3 -fobjc-arc -F/System/Library/PrivateFrameworks/ -framework AppKit -framework Carbon -framework SkyLight $< -o $@

bin:
	mkdir bin
