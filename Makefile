.PHONY: install update format lint test clean download-data test-all

install:
	shards install

update:
	shards update

format:
	crystal tool format src spec

lint:
	ameba src spec

test:
	crystal spec

test-all: download-data
	crystal spec

clean:
	rm -rf lib/

# Test data from HuggingFace tokenizers-test-data
# Some integration tests need these files to run.
HF_DATA = https://huggingface.co/datasets/hf-internal-testing/tokenizers-test-data/resolve/main
DATA_DIR = data

$(DATA_DIR):
	mkdir -p $@

$(DATA_DIR)/gpt2-vocab.json: | $(DATA_DIR)
	curl -sL $(HF_DATA)/gpt2-vocab.json -o $@

$(DATA_DIR)/gpt2-merges.txt: | $(DATA_DIR)
	curl -sL $(HF_DATA)/gpt2-merges.txt -o $@

$(DATA_DIR)/small.txt: | $(DATA_DIR)
	curl -sL $(HF_DATA)/small.txt -o $@

$(DATA_DIR)/unigram.json: | $(DATA_DIR)
	curl -sL $(HF_DATA)/unigram.json -o $@

$(DATA_DIR)/albert-base-v1-tokenizer.json: | $(DATA_DIR)
	curl -sL $(HF_DATA)/albert-base-v1-tokenizer.json -o $@

$(DATA_DIR)/bert-base-uncased-vocab.txt: | $(DATA_DIR)
	curl -sL $(HF_DATA)/bert-base-uncased-vocab.txt -o $@

$(DATA_DIR)/llama-3-tokenizer.json: | $(DATA_DIR)
	curl -sL $(HF_DATA)/llama-3-tokenizer.json -o $@

$(DATA_DIR)/roberta.json: | $(DATA_DIR)
	curl -sL $(HF_DATA)/roberta.json -o $@

$(DATA_DIR)/tokenizer-wiki.json: | $(DATA_DIR)
	curl -sL $(HF_DATA)/tokenizer-wiki.json -o $@

$(DATA_DIR)/bert-wiki.json: | $(DATA_DIR)
	curl -sL $(HF_DATA)/bert-wiki.json -o $@

# Minimal set needed for integration tests
download-data: $(DATA_DIR)/gpt2-vocab.json $(DATA_DIR)/gpt2-merges.txt $(DATA_DIR)/small.txt $(DATA_DIR)/unigram.json $(DATA_DIR)/albert-base-v1-tokenizer.json $(DATA_DIR)/bert-base-uncased-vocab.txt $(DATA_DIR)/llama-3-tokenizer.json $(DATA_DIR)/roberta.json $(DATA_DIR)/tokenizer-wiki.json $(DATA_DIR)/bert-wiki.json
