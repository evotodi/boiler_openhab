SHELL   = /bin/bash
ASDF := $(shell bash -c 'echo -e "Carefully type in the following prompts!\nLeave blank to not update the value.\n" 1>&2')
HM_URL := $(shell bash -c 'read -p "Boiler URL: " url; echo $$url')
IPADDY := $(shell bash -c "ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'")

install: first addOpenhabUser setupOpenhabDir setupMqttDir setupEnvFile setupBoilerDir dockerBuild dockerUp
	@echo
	@echo Setup Complete!
	@echo
	@echo If this is the first install please allow 5-10 minutes for openhab to startup
	@echo
	@echo Openhab will be available at http://$(IPADDY):8080
	@echo

first:
	@echo Beginning setup...
ifeq (,$(wildcard .env))
	touch .env
	echo "USER_ID=xxx" >> .env
	echo "GROUP_ID=xxx" >> .env
	echo "HM_URL=xxx" >> .env
endif
	-docker compose down

addOpenhabUser:
	-useradd -r -s /sbin/nologin openhab
	usermod -a -G openhab openhab

setupOpenhabDir:
	mkdir -p openhab/{addons,conf,userdata}
	chown -R openhab:openhab ./openhab

setupMqttDir:
	mkdir -p mqtt/{config,data,log}
	chown -R server:users ./mqtt
	chmod 700 ./mqtt/config/pwfile

setupBoilerDir:
ifneq (,$(wildcard ./boiler))
	git -C ./boiler pull
else
	git clone https://github.com/evotodi/boiler_status ./boiler
endif

setupEnvFile:
ifneq ($(strip $(HM_URL)),)
	URL=$(HM_URL) && echo $$URL && sed -i -e "s#HM_URL=.*#HM_URL=$$URL#g" .env
endif
	sed -i -e "s/USER_ID=.*/USER_ID=\"$$(id -u openhab)\"/g" .env
	sed -i -e "s/GROUP_ID=.*/GROUP_ID=\"$$(id -g openhab)\"/g" .env

dockerBuild:
	docker compose build mqtt
	docker compose build boiler
	docker compose build openhab

dockerUp:
	docker compose up -d
	docker ps