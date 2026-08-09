import openai/chat as chat
import openai/responses as responses

block scoped_helper_names:
  let chatPart = chat.partText("chat")
  let responsePart = responses.partText("response")
  doAssert chatPart.text == "chat"
  doAssert responsePart.text == "response"
