set dotenv-load

src := "src/"
binary := "into_the_depths"

default:
    @just --list

build:
    odin build {{src}} -out:{{binary}}

run:
    odin run {{src}}

run-built: build
    ./{{binary}}

clean:
    rm -f {{binary}}
