# Lunch Lottery


## Install:
`pip install -r requirements.txt`

Make sure you set the following env vars:

secret env vars:

`BOT_TOKEN=xoxb-xx-xx-xx`

`OAUTH_BOT_TOKEN=xoxp-xx-xx-xx-xx`

config env vars:

Staging:

`BOT_NAME=LunchLottoBot`

`CHANNEL=test-lunch-lotto`

`NUMBER_OF_WINNERS=1`

`PER_PERSON_BUDGET=Z`

`ENVIRONMENT=staging`

Production:

`BOT_NAME=LunchLottoBot`

`CHANNEL=office`

`NUMBER_OF_WINNERS=3`

`PER_PERSON_BUDGET=20`

`ENVIRONMENT=PRODUCTION`

## Deploy:

`sh deploy/deploy.sh bot staging . . ./Dockerfile`

Deploys three cron jobs: start, remind, end

## Usage

```python
python bot.py help
```
```
Slackbot for the Office Lunch Lottery.
python bot.py help      Show this text
python bot.py start     Start a new lottery for the week
python bot.py remind    Send a reminder message to participate
python bot.py end       Finish this lottery and notify winners
```