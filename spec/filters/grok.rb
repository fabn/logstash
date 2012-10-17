require "test_utils"
require "logstash/filters/grok"

describe LogStash::Filters::Grok do
  extend LogStash::RSpec

  describe "simple syslog line" do
    # The logstash config goes here.
    # At this time, only filters are supported.
    config <<-CONFIG
      filter {
        grok {
          pattern => "%{SYSLOGLINE}"
          singles => true
        }
      }
    CONFIG

    sample "Mar 16 00:01:25 evita postfix/smtpd[1713]: connect from camomile.cloud9.net[168.100.1.3]" do
      reject { subject["@tags"] }.include?("_grokparsefailure")
      insist { subject["logsource"] } == "evita"
      insist { subject["timestamp"] } == "Mar 16 00:01:25"
      insist { subject["message"] } == "connect from camomile.cloud9.net[168.100.1.3]"
      insist { subject["program"] } == "postfix/smtpd"
      insist { subject["pid"] } == "1713"
    end
  end

  describe "complex syslog line" do
    # The logstash config goes here.
    # At this time, only filters are supported.
    config <<-CONFIG
      filter {
        grok {
          pattern => "%{POSTFIXSMTPLOG}"
          singles => true
        }
      }
    CONFIG

    sample "Oct  2 06:55:04 mail20 postfix/smtp[17714]: B89F93CC26: to=<dyyy.vxxx@gmail.com>, relay=gmail-smtp-in.l.google.com[74.125.45.27]:25, delay=0.84, delays=0.3/0.01/0.15/0.38, dsn=2.0.0, status=sent (250 2.0.0 OK 1349175304 r68si528134yhc.107)" do
      reject { subject["@tags"] }.include?("_grokparsefailure")
      insist { subject["logsource"] } == "mail20"
      insist { subject["timestamp"] } == "Oct  2 06:55:04"
      insist { subject["program"] } == "postfix/smtp"
      insist { subject["pid"] } == "17714"
      insist { subject["queue_id"] } == "B89F93CC26"
      insist { subject["to"] } == "<dyyy.vxxx@gmail.com>"
      insist { subject["ip"] } == "74.125.45.27"
    end
  end

  describe "parsing an event with multiple messages (array of strings)" do
    config <<-CONFIG
      filter {
        grok {
          pattern => "(?:hello|world) %{NUMBER}"
          named_captures_only => false
        }
      }
    CONFIG

    sample({ "@message" => [ "hello 12345", "world 23456" ] }) do
      insist { subject["NUMBER"] } == [ "12345", "23456" ] 
    end
  end

  describe "coercing matched values" do
    config <<-CONFIG
      filter {
        grok {
          pattern => "%{NUMBER:foo:int} %{NUMBER:bar:float}"
          singles => true
        }
      }
    CONFIG

    sample "400 454.33" do
      insist { subject["foo"] } == 400
      insist { subject["foo"] }.is_a?(Fixnum)
      insist { subject["bar"] } == 454.33
      insist { subject["bar"] }.is_a?(Float)
    end
  end

  describe "in-line pattern definitions" do
    config <<-CONFIG
      filter {
        grok {
          pattern => "%{FIZZLE=\\d+}"
          named_captures_only => false
          singles => true
        }
      }
    CONFIG

    sample "hello 1234" do
      insist { subject["FIZZLE"] } == "1234"
    end
  end

  describe "processing fields other than @message" do
    config <<-CONFIG
      filter {
        grok {
          pattern => "%{WORD:word}"
          match => [ "examplefield", "%{NUMBER:num}" ]
          break_on_match => false
          singles => true
        }
      }
    CONFIG

    sample({ "@message" => "hello world", "@fields" => { "examplefield" => "12345" } }) do
      insist { subject["examplefield"] } == "12345"
      insist { subject["word"] } == "hello"
    end
  end

  describe "adding fields on match" do
    config <<-CONFIG
      filter {
        grok {
          pattern => "matchme %{NUMBER:fancy}"
          singles => true
          add_field => [ "new_field", "%{fancy}" ]
        }
      }
    CONFIG

    sample "matchme 1234" do
      reject { subject["@tags"] }.include?("_grokparsefailure")
      insist { subject["new_field"] } == ["1234"]
    end

    sample "this will not be matched" do
      insist { subject["@tags"] }.include?("_grokparsefailure")
      reject { subject }.include?("new_field")
    end
  end

  context "empty fields" do
    describe "drop by default" do
      config <<-CONFIG
        filter {
          grok {
            pattern => "1=%{WORD:foo1} *(2=%{WORD:foo2})?"
          }
        }
      CONFIG

      sample "1=test" do
        reject { subject["@tags"] }.include?("_grokparsefailure")
        insist { subject }.include?("foo1")

        # Since 'foo2' was not captured, it must not be present in the event.
        reject { subject }.include?("foo2")
      end
    end

    describe "keep if keep_empty_captures is true" do
      config <<-CONFIG
        filter {
          grok {
            pattern => "1=%{WORD:foo1} *(2=%{WORD:foo2})?"
            keep_empty_captures => true
          }
        }
      CONFIG

      sample "1=test" do
        reject { subject["@tags"] }.include?("_grokparsefailure")
        insist { subject }.include?("foo1")
        insist { subject }.include?("foo2")
      end
    end
  end

  describe "when named_captures_only == false" do
    config <<-CONFIG
      filter {
        grok {
          pattern => "Hello %{WORD}. %{WORD:foo}"
          named_captures_only => false
          singles => true
        }
      }
    CONFIG

    sample "Hello World, yo!" do
      insist { subject }.include?("WORD")
      insist { subject["WORD"] } == "World"
      insist { subject }.include?("foo")
      insist { subject["foo"] } == "yo"
    end
  end
end
