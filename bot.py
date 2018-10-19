import os
import sys
import time
from random import sample
from slackclient import SlackClient

BOT_TOKEN = os.environ['BOT_TOKEN']
OAUTH_BOT_TOKEN = os.environ['OAUTH_BOT_TOKEN']

def use_env_or_set(ENVVAR, val):
    return val if ENVVAR not in os.environ else os.environ[ENVVAR]

BOT_NAME = use_env_or_set('BOT_NAME', 'LunchLottoBot')
CHANNEL = use_env_or_set('CHANNEL', 'test-lunch-lotto')
NUMBER_OF_WINNERS = int(use_env_or_set('NUMBER_OF_WINNERS', 1))
PER_PERSON_BUDGET = use_env_or_set('PER_PERSON_BUDGET', 'X')
# Default to use staging environment
ENVIRONMENT = use_env_or_set('ENVIRONMENT', 'STAGING')

FIRST_MESSAGE = "Thumbs up :+1: to be added to this week's lunch lottery! Entries close on Tuesday at noon PST! We will then draw {NUMBER_OF_WINNERS} winners to get lunch together with a budget of ${PER_PERSON_BUDGET} per person."
REMINDER_MESSAGE = "Only two hours left until this week's lunch lottery closes! Scroll up to my previous message to enter!"
ANNOUNCE_WINNER_MESSAGE = "This week's lucky winners are {WINNERS}! Stay tuned for the next lunch lottery!"
CONGRATS_MESSAGE1 = "Lucky you! Please find a date to grab lunch *within 7 days* and remember to cancel your Eat Club order for that day."
CONGRATS_MESSAGE2 = "If you cannot make things work out this week, please invite someone else who participated!"

def get_channel_id(channel_name):
    channels = sc.api_call(
        "conversations.list",
        limit=1000,
        types='public_channel,private_channel')['channels']
    channel_id = [c['id'] for c in channels if c['name'] == channel_name][0]
    return channel_id

def start_lottery():
    if ENVIRONMENT == "STAGING":
        message = sc.api_call(
            "chat.postMessage",
            channel=CHANNEL,
            text="Testing!"
        )
    message = sc.api_call(
        "chat.postMessage",
        channel=CHANNEL,
        text=FIRST_MESSAGE.format(NUMBER_OF_WINNERS = NUMBER_OF_WINNERS, PER_PERSON_BUDGET = PER_PERSON_BUDGET)
    )
    timestamp = message['ts']
    channel_id = get_channel_id(CHANNEL)
    # React to initial image so people can easily click it
    a = sc.api_call(
        "reactions.add",
        channel=channel_id,
        name="+1",
        timestamp=timestamp
    )

def get_participants():

    channel_id = get_channel_id(CHANNEL)

    # Find the initial post
    # Search for the first few words of the first message
    query = ' '.join(FIRST_MESSAGE[:50].split(' ')[:-1])
    res = oauth_sc.api_call(
        "search.messages",
        query = 'in:' + CHANNEL + ' ' + query
    )
    matches = res['messages']['matches']
    matches_from_bot = [m for m in matches if m['username'].lower() == BOT_NAME.lower()]
    # Since they are sorted by most recent, we take the first result
    timestamp = matches_from_bot[0]['ts']

    # Get all the reactions on that post
    initial_post_reactions = oauth_sc.api_call(
        "reactions.get",
        channel = channel_id,
        timestamp = timestamp
    )
    all_reactions = initial_post_reactions['message']['reactions']

    # Only count the specific reaction
    target_reaction = [r for r in all_reactions if r['name'] == "+1"][0]
    participants = target_reaction['users']

    # To filter out the bot's reaction, we have to get the bot's user_id
    bot_id = initial_post_reactions['message']['bot_id']
    bot_info = sc.api_call(
        "bots.info",
        bot = bot_id
    )
    bot_user_id = bot_info['bot']['user_id']
    
    # filter out the bot's initial reaction
    filtered_participants= [w for w in participants if w != bot_user_id]
    return filtered_participants

def send_reminder():
    message = sc.api_call(
        "chat.postMessage",
        channel=CHANNEL,
        text=REMINDER_MESSAGE
    )

def choose_winners(participants):
    if len(participants) == 1:
        return participants
    else:
        return sample(participants, NUMBER_OF_WINNERS)

def create_winners_channel(winners):
    new_channel = sc.api_call(
        "conversations.open",
        users=winners
    )
    new_channel_id = new_channel['channel']['id']
    sc.api_call(
        "chat.postMessage",
        channel=new_channel_id,
        text=CONGRATS_MESSAGE1
    )
    sc.api_call(
        "chat.postMessage",
        channel=new_channel_id,
        text=CONGRATS_MESSAGE2
    )

def format_winners_list(winners):
    # Convert list of user id's to username mentions in slack
    if len(winners) == 1:
        return '<@'+winners[0]+'>'
    else:
        winner_mentions = []
        for w in winners:
            winner_mentions.append('<@'+w+'>')
        return ', '.join(map(str, winner_mentions[:-1])) + ' and ' + winner_mentions[-1] 

def announce_results(winners):
    formatted_winners_list = format_winners_list(winners)
    message = sc.api_call(
        "chat.postMessage",
        channel=CHANNEL,
        text=ANNOUNCE_WINNER_MESSAGE.format(WINNERS = formatted_winners_list)
    )

def end_lottery():
    filtered_participants = get_participants()
    winners = choose_winners(filtered_participants)
    create_winners_channel(winners)
    announce_results(winners)

def usage(exit_code=0):
    usage_text = """Slackbot for the Office Lunch Lottery.
python bot.py help      Show this text
python bot.py start     Start a new lottery for the week
python bot.py remind    Send a reminder message to participate
python bot.py end       Finish this lottery and notify winners
"""
    print usage_text
    exit(exit_code)

if __name__ == '__main__':
    sc = SlackClient(BOT_TOKEN)
    oauth_sc = SlackClient(OAUTH_BOT_TOKEN)
    if not sc.rtm_connect():
        raise Exception("Couldn't connect to slack.")
    if len(sys.argv) == 1:
        usage()
    elif sys.argv[1] == "help" or sys.argv[1] == "--help":
        usage()
    elif sys.argv[1] == "start":
        start_lottery()
    elif sys.argv[1] == "remind":
        send_reminder()
    elif sys.argv[1] == "end":
        end_lottery()
    else:
        print "Invalid option: " + sys.argv[1]
        usage(1)
