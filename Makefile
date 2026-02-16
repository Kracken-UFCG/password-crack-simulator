PORT ?= 8081
FRONT_DIR = src/front

build:
	bash utils/download_data.sh

help:
	@echo "  make run-front    - Runs front server on $(PORT)."
	@echo "  make run-front PORT=3000 - Runs on your port choice."

run-front:
	@echo "Front is running on http://localhost:$(PORT)"
	@echo "Press CTRL+C to stop."
	@python3 -m http.server $(PORT) --directory $(FRONT_DIR)
