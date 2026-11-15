.PHONY: app install run test screenshots clean

app:
	scripts/build-app.sh

install:
	scripts/install-app.sh

run: app
	open build/Camera.app

test:
	swift test

screenshots:
	scripts/screenshots.sh

clean:
	rm -rf .build build
