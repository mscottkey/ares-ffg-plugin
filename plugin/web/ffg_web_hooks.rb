module AresMUSH
  module Ffg
    class GetChargenInfoRequestHandler
      def handle(request)
        char = request.enactor
        error = Website.check_login(request)
        return error if error

        {
          char: Ffg.build_web_char_data(char, char, true),
          cg_ffg: Ffg.build_web_chargen_info
        }
      end
    end
  end
end