.PHONY: app install package run test screenshots clean

app:
	scripts/build-app.sh

install:
	scripts/install-app.sh

package:
	scripts/package-app.sh

run: app
	open build/Camera.app

test:
	swift test

screenshots:
	scripts/screenshots.sh

clean:
	rm -rf .build build
