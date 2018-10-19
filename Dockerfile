FROM python:2.7

MAINTAINER NickLavrov

ADD bot.py /
ADD requirements.txt /

RUN pip install -r requirements.txt

CMD [ "python", "./bot.py" ]
