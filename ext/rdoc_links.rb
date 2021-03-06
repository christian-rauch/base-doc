require 'webgen/tag'
class RdocLinks
    include Webgen::Tag::Base

    def call(tag, body, context)
        name = param('rdoclinks.name')
        if base_module = param('rdoclinks.base_module')
            name = base_module + "::" + name
        end

        if name =~ /(?:\.|#)(\w+)$/
            class_name  = $` 
            method_name = $1
        else
            class_name = name
        end

        path = class_name.split('::')
        path[-1] += ".html"
        url = "#{param('rdoclinks.base_url')}/#{path.join("/")}"

        "<a href=\"#{context.ref_node.route_to(url)}\">#{param('rdoclinks.text') || param('rdoclinks.name')}</a>"
    end
end

class RdocPath
    include Webgen::Tag::Base

    def call(tag, body, context)
        name = param('rdocpath.name')
        if base_module = param('rdocpath.base_module')
            name = base_module + "::" + name
        end

        if name =~ /(?:\.|#)(\w+)$/
            class_name  = $` 
            method_name = $1
        else
            class_name = name
        end

        path = class_name.split('::')
        path[-1] += ".html"
        "#{param('rdocpath.base_url')}/#{path.join("/")}"
    end
end

config = Webgen::WebsiteAccess.website.config
config.rdoclinks.name        "", :mandatory => 'default'
config.rdoclinks.base_url    "", :mandatory => false
config.rdoclinks.base_module nil, :mandatory => false
config.rdoclinks.full_name   false, :mandatory => false
config.rdoclinks.text   nil, :mandatory => false
config['contentprocessor.tags.map']['rdoc_class'] = 'RdocLinks'
config.rdocpath.name        "", :mandatory => 'default'
config.rdocpath.base_url    "", :mandatory => false
config.rdocpath.base_module nil, :mandatory => false
config['contentprocessor.tags.map']['rdoc_path'] = 'RdocPath'


