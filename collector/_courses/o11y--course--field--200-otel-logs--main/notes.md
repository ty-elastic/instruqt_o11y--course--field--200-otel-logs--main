^(?P<ip>(?:\d+\.?){4}) - - \[(?P<timestamp>.*?)\] \"(?P<action>GET|PUT|PATCH|HEAD|DELETE|POST)\s(?P<path>.*?)\s(?P<protocol>.*?)\" (?P<status_code>[1-5][0-9][0-9]).*$

%{IP:clientip} - - \[%{GREEDYDATA:timestamp}\] \"%{WORD:action} %{URIPATHPARAM:request} %{WORD:protocol}/%{NUMBER:protocolNum}\" %{NUMBER:response} -