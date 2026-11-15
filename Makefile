.PHONY: app install run test clean

app:
	scripts/build-app.sh

install:
	scripts/install-app.sh

run: app
	open build/Camera.app

test:
	swift test

clean:
	rm -rf .build build
