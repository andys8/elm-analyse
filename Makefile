.PHONY: html test validate-js-format validate-elm-format lint-js

build: tsc elm-backend elm-client elm-docs editor html

tsc:
	./node_modules/.bin/tsc

elm-backend:
	./node_modules/.bin/elm-make src/Analyser.elm --output dist/app/backend-elm.js

elm-client:
	./node_modules/.bin/elm-make src/Client.elm --output dist/public/client-elm.js

elm-docs:
	./node_modules/.bin/elm-make docs/Docs/Main.elm --output docs/docs.js

html:
	./node_modules/.bin/gulp html
	mkdir -p dist/public/bootstrap
	cp ./node_modules/bootstrap/dist/css/bootstrap.min.css dist/public/bootstrap/bootstrap-v3.3.7.css
	cp ./node_modules/sb-admin-2/dist/css/sb-admin-2.css dist/public/bootstrap/start-bootstrap-admin-2_v3.3.7.css
	mkdir -p dist/public/font-awesome/4.7.0
	cp -rf ./node_modules/font-awesome/css dist/public/font-awesome/4.7.0/
	cp -rf ./node_modules/font-awesome/fonts dist/public/font-awesome/4.7.0/
	# cp -rf ./static/* dist/public/


validate: validate-js-format validate-elm-format lint-js lint-elm

lint-js:
	./node_modules/.bin/eslint js

validate-js-format:
	./prettier-check.sh

lint-elm:
	node ./dist/app/bin/index.js

validate-elm-format:
	./node_modules/.bin/elm-format --validate src/ tests/ docs/

test:
	./node_modules/.bin/elm-test --compiler ./node_modules/.bin/elm-test

clean:
	rm -rf dist

editor: tsc
	./node_modules/.bin/elm-make src/Editor.elm --output dist/app/editor/elm.js
	mkdir -p dist/public
	node build-editor.js

prepare: prepare-npm prepare-elm

prepare-npm: package.json
	npm install

prepare-elm:
	./node_modules/.bin/elm-package install -y
	cd tests && ../node_modules/.bin/elm-package install -y

run:
	node dist/app/bin/index.js

run-server:
	node dist/app/bin/index.js -s
