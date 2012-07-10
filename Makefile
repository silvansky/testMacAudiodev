CC=clang++
OPTS=-Wall -pedantic
LOPTS=-lobjc -framework CoreAudio -framework Carbon -framework Cocoa
SOURCES=$(wildcard *.mm)
OBJECTS=$(SOURCES:.mm=.o)

TARGET=testca

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LOPTS) -o $@ $^

%.o : %.mm
	$(CC) -c $(OPTS) $<

clean:
	rm $(TARGET) $(OBJECTS)

install:
	cp $(TARGET) /usr/local/bin/

uninstall:
	rm /usr/local/bin/$(TARGET)

