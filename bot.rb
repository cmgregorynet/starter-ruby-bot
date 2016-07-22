require 'slack-ruby-client'
require 'logging'
require_relative 'street_scraper'
require 'redis'
require 'byebug'

logger = Logging.logger(STDOUT)
logger.level = :debug

Slack.configure do |config|
  config.token = ENV['SLACK_TOKEN']
  if not config.token
    logger.fatal('Missing ENV[SLACK_TOKEN]! Exiting program')
    exit
  end
end

client = Slack::RealTime::Client.new

players_to_points = Redis.new

# listen for hello (connection) event - https://api.slack.com/events/hello
client.on :hello do
  logger.debug("Connected '#{client.self['name']}' to '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com.")
end

# listen for message event - https://api.slack.com/events/message
poke_spotted = false

client.on :message do |data|

  case data['text']
    when 'streets' then
      client.typing channel: data['channel']
      client.message channel: data['channel'], text: "Hello <@#{data['user']}>."
      logger.debug("<@#{data['user']}> said hi")

      if direct_message?(data)
        client.message channel: data['channel'], text: "It\'s nice to talk to you directly."
        logger.debug("And it was a direct message")
      end

      street_scraper = StreetScraper.new
      street_scraper.get_street_names
      street_scraper.create_channels(1, client.web_client)

    when /spotted(.*)/ then
      poke_spotted = true

    when /missed(.*)/ then
      poke_spotted = true

    when /^go/ then
      if poke_spotted
        poke_spotted = false
        points = players_to_points.get(data['user']).to_i
        puts points

        points = points + 1

        players_to_points.set(data['user'], points)
      end

    when 'score'
      points = players_to_points.get(data['user'])
      client.message channel: data['channel'], text: "Your points: #{points}"

    when 'attachment', 'bot attachment' then
      # attachment messages require using web_client
      client.web_client.chat_postMessage(post_message_payload(data))
      logger.debug("Attachment message posted")

    when bot_mentioned(client)
      client.message channel: data['channel'], text: 'You really do care about me. :heart:'
      logger.debug("Bot mentioned in channel #{data['channel']}")

    when 'bot help', 'help' then
      client.message channel: data['channel'], text: help
      logger.debug("A call for help")

    when /^bot/ then
      client.message channel: data['channel'], text: "Sorry <@#{data['user']}>, I don\'t understand. \n#{help}"
      logger.debug("Unknown command")
  end
end

def direct_message?(data)
  # direct message channles start with a 'D'
  data['channel'][0] == 'D'
end

def bot_mentioned(client)
  # match on any instances of `<@bot_id>` in the message
  /\<\@#{client.self['id']}\>+/
end

def joiner_is_bot?(client, data)
 /^\<\@#{client.self['id']}\>/.match data['channel']['latest']['text']
end

def help
  %Q(I will respond to the following messages: \n
      `bot hi` for a simple message.\n
      `bot attachment` to see a Slack attachment message.\n
      `@<your bot\'s name>` to demonstrate detecting a mention.\n
      `bot help` to see this again.)
end

def post_message_payload(data)
  main_msg = 'Beep Beep Boop is a ridiculously simple hosting platform for your Slackbots.'
  {
    channel: data['channel'],
      as_user: true,
      attachments: [
        {
          fallback: main_msg,
          pretext: 'We bring bots to life. :sunglasses: :thumbsup:',
          title: 'Host, deploy and share your bot in seconds.',
          image_url: 'https://storage.googleapis.com/beepboophq/_assets/bot-1.22f6fb.png',
          title_link: 'https://beepboophq.com/',
          text: main_msg,
          color: '#7CD197'
        }
      ]
  }
end

client.start!
