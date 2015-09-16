class AbstractChosen

  constructor: (@form_field, @options={}) ->
    return unless AbstractChosen.browser_is_supported()
    @is_multiple = @form_field.multiple
    this.set_default_text()
    this.set_default_values()

    this.setup()

    this.set_up_html()
    this.register_observers()

  set_default_values: ->
    @click_test_action = (evt) => this.test_active_click(evt)
    @activate_action = (evt) => this.activate_field(evt)
    @active_field = false
    @mouse_on_container = false
    @results_showing = false
    @result_highlighted = null
    @allow_single_deselect = if @options.allow_single_deselect? and @form_field.options[0]? and @form_field.options[0].text is "" then @options.allow_single_deselect else false
    @disable_search_threshold = @options.disable_search_threshold || 0
    @disable_search = @options.disable_search || false
    @enable_split_word_search = if @options.enable_split_word_search? then @options.enable_split_word_search else true
    @group_search = if @options.group_search? then @options.group_search else true
    @search_contains = @options.search_contains || false
    @single_backstroke_delete = if @options.single_backstroke_delete? then @options.single_backstroke_delete else true
    @max_selected_options = @options.max_selected_options || Infinity
    @inherit_select_classes = @options.inherit_select_classes || false
    @display_selected_options = if @options.display_selected_options? then @options.display_selected_options else true
    @display_disabled_options = if @options.display_disabled_options? then @options.display_disabled_options else true
    @create_option = @options.create_option || false
    @persistent_create_option = @options.persistent_create_option || false
    @skip_no_results = @options.skip_no_results || false

  set_default_text: ->
    if @form_field.getAttribute("data-placeholder")
      @default_text = @form_field.getAttribute("data-placeholder")
    else if @is_multiple
      @default_text = @options.placeholder_text_multiple || @options.placeholder_text || AbstractChosen.default_multiple_text
    else
      @default_text = @options.placeholder_text_single || @options.placeholder_text || AbstractChosen.default_single_text

    @results_none_found = @form_field.getAttribute("data-no_results_text") || @options.no_results_text || AbstractChosen.default_no_result_text
    @create_option_text = @form_field.getAttribute("data-create_option_text") || @options.create_option_text || AbstractChosen.default_create_option_text

  mouse_enter: -> @mouse_on_container = true
  mouse_leave: -> @mouse_on_container = false

  input_focus: (evt) ->
    if @is_multiple
      setTimeout (=> this.container_mousedown()), 50 unless @active_field
    else
      @activate_field() unless @active_field

  input_blur: (evt) ->
    if not @mouse_on_container
      @active_field = false
      setTimeout (=> this.blur_test()), 100

  results_option_build: (options) ->
    content = ''
    for data in @results_data
      if data.group
        content += this.result_add_group data
      else
        content += this.result_add_option data

      # this select logic pins on an awkward flag
      # we can make it better
      if options?.first
        if data.selected and @is_multiple
          this.choice_build data
        else if data.selected and not @is_multiple
          this.single_set_selected_text(data.text)

    content

  result_add_option: (option) ->
    return '' unless option.search_match
    return '' unless this.include_option_in_results(option)

    classes = []
    classes.push "active-result" if !option.disabled and !(option.selected and @is_multiple)
    classes.push "disabled-result" if option.disabled and !(option.selected and @is_multiple)
    classes.push "result-selected" if option.selected
    classes.push "group-option" if option.group_array_index?
    classes.push option.classes if option.classes != ""

    option_el = document.createElement("li")
    option_el.className = classes.join(" ")
    option_el.style.cssText = option.style
    option_el.setAttribute("data-option-array-index", option.array_index)
    option_el.innerHTML = option.search_text

    this.outerHTML(option_el)

  result_add_group: (group) ->
    return '' unless group.search_match || group.group_match
    return '' unless group.active_options > 0

    group_el = document.createElement("li")
    group_el.className = "group-result"
    group_el.innerHTML = group.search_text

    this.outerHTML(group_el)

  append_option: (option) ->
    this.select_append_option(option)

  results_update_field: ->
    this.set_default_text()
    this.results_reset_cleanup() if not @is_multiple
    this.result_clear_highlight()
    this.results_build()
    this.winnow_results() if @results_showing

  reset_single_select_options: () ->
    for result in @results_data
      result.selected = false if result.selected

  results_toggle: ->
    if @results_showing
      this.results_hide()
    else
      this.results_show()

  results_search: (evt) ->
    if @results_showing
      this.winnow_results()
    else
      this.results_show()

  winnow_results: ->
    this.no_results_clear()

    results = 0
    exact_result = false

    searchText = this.get_search_text()
    escapedSearchText = searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")
    zregex = new RegExp(escapedSearchText, 'i')
    regex = this.get_search_regex(escapedSearchText)
    eregex = new RegExp('^' + escapedSearchText + '$', 'i')

    for option in @results_data

      option.search_match = false
      results_group = null

      if this.include_option_in_results(option)

        if option.group
          option.group_match = false
          option.active_options = 0

        if option.group_array_index? and @results_data[option.group_array_index]
          results_group = @results_data[option.group_array_index]
          results += 1 if results_group.active_options is 0 and results_group.search_match
          results_group.active_options += 1

        unless option.group and not @group_search

          option.search_text = if option.group then option.label else option.text
          option.search_match = this.search_string_match(option.search_text, regex)
          results += 1 if option.search_match and not option.group

          exact_result = eregex.test option.html

          if option.search_match
            if searchText.length
              startpos = option.search_text.search zregex
              text = option.search_text.substr(0, startpos + searchText.length) + '</em>' + option.search_text.substr(startpos + searchText.length)
              option.search_text = text.substr(0, startpos) + '<em>' + text.substr(startpos)

            results_group.group_match = true if results_group?

          else if option.group_array_index? and @results_data[option.group_array_index].search_match
            option.search_match = true

    this.result_clear_highlight()

    if results < 1 and searchText.length
      this.update_results_content ""
      this.no_results searchText unless @create_option and @skip_no_results
    else
      this.update_results_content this.results_option_build()
      this.winnow_results_set_highlight()

    if @create_option and (results < 1 or (!exact_result and @persistent_create_option)) and searchText.length
      this.show_create_option( searchText )

  get_search_regex: (escaped_search_string) ->
    regex_anchor = if @search_contains then "" else "^"
    new RegExp(regex_anchor + escaped_search_string, 'i')

  search_string_match: (search_string, regex) ->
    if regex.test search_string
      return true
    else if @enable_split_word_search and (search_string.indexOf(" ") >= 0 or search_string.indexOf("[") == 0)
      #TODO: replace this substitution of /\[\]/ with a list of characters to skip.
      parts = search_string.replace(/\[|\]/g, "").split(" ")
      if parts.length
        for part in parts
          if regex.test part
            return true

  choices_count: ->
    return @selected_option_count if @selected_option_count?

    @selected_option_count = 0
    for option in @form_field.options
      @selected_option_count += 1 if option.selected

    return @selected_option_count

  choices_click: (evt) ->
    evt.preventDefault()
    this.results_show() unless @results_showing or @is_disabled

  keyup_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    switch stroke
      when 8
        if @is_multiple and @backstroke_length < 1 and this.choices_count() > 0
          this.keydown_backstroke()
        else if not @pending_backstroke
          this.result_clear_highlight()
          this.results_search()
      when 13
        evt.preventDefault()
        this.result_select(evt) if this.results_showing
      when 27
        this.results_hide() if @results_showing
        return true
      when 9, 38, 40, 16, 91, 17
        # don't do anything on these keys
      else this.results_search()

  clipboard_event_checker: (evt) ->
    setTimeout (=> this.results_search()), 50

  container_width: ->
    return if @options.width? then @options.width else "#{@form_field.offsetWidth}px"

  include_option_in_results: (option) ->
    return false if @is_multiple and (not @display_selected_options and option.selected)
    return false if not @display_disabled_options and option.disabled
    return false if option.empty

    return true

  search_results_touchstart: (evt) ->
    @touch_started = true
    this.search_results_mouseover(evt)

  search_results_touchmove: (evt) ->
    @touch_started = false
    this.search_results_mouseout(evt)

  search_results_touchend: (evt) ->
    this.search_results_mouseup(evt) if @touch_started

  outerHTML: (element) ->
    return element.outerHTML if element.outerHTML
    tmp = document.createElement("div")
    tmp.appendChild(element)
    tmp.innerHTML

  # class methods and variables ============================================================

  @browser_is_supported: ->
    if window.navigator.appName == "Microsoft Internet Explorer"
      return document.documentMode >= 8
    if /iP(od|hone)/i.test(window.navigator.userAgent)
      return false
    if /Android/i.test(window.navigator.userAgent)
      return false if /Mobile/i.test(window.navigator.userAgent)
    return true

  @default_multiple_text: "Select Some Options"
  @default_single_text: "Select an Option"
  @default_no_result_text: "No results match"
  @default_create_option_text: "Add Option"


class SelectParser

  constructor: ->
    @options_index = 0
    @parsed = []

  add_node: (child) ->
    if child.nodeName.toUpperCase() is "OPTGROUP"
      this.add_group child
    else
      this.add_option child

  add_group: (group) ->
    group_position = @parsed.length
    @parsed.push
      array_index: group_position
      group: true
      label: this.escapeExpression(group.label)
      title: group.title if group.title
      children: 0
      disabled: group.disabled,
      classes: group.className
    this.add_option( option, group_position, group.disabled ) for option in group.childNodes

  add_option: (option, group_position, group_disabled) ->
    if option.nodeName.toUpperCase() is "OPTION"
      if option.text != ""
        if group_position?
          @parsed[group_position].children += 1
        @parsed.push
          array_index: @parsed.length
          options_index: @options_index
          value: option.value
          text: option.text
          html: option.innerHTML
          title: option.title if option.title
          selected: option.selected
          disabled: if group_disabled is true then group_disabled else option.disabled
          group_array_index: group_position
          group_label: if group_position? then @parsed[group_position].label else null
          classes: option.className
          style: option.style.cssText
      else
        @parsed.push
          array_index: @parsed.length
          options_index: @options_index
          empty: true
      @options_index += 1

  escapeExpression: (text) ->
    if not text? or text is false
      return ""
    unless /[\&\<\>\"\'\`]/.test(text)
      return text
    map =
      "<": "&lt;"
      ">": "&gt;"
      '"': "&quot;"
      "'": "&#x27;"
      "`": "&#x60;"
    unsafe_chars = /&(?!\w+;)|[\<\>\"\'\`]/g
    text.replace unsafe_chars, (chr) ->
      map[chr] || "&amp;"

SelectParser.select_to_array = (select) ->
  parser = new SelectParser()
  parser.add_node( child ) for child in select.childNodes
  parser.parsed


window.SelectParser = SelectParser


$ = jQuery    #poop

$.fn.extend({
  chosen: (options) ->
    # Do no harm and return as soon as possible for unsupported browsers, namely IE6 and IE7
    # Continue on if running IE document type but in compatibility mode
    return this unless AbstractChosen.browser_is_supported()
    this.each (input_field) ->
      $this = $ this
      chosen = $this.data('chosen')
      if options is 'destroy' && chosen instanceof Chosen
        chosen.destroy()
      else unless chosen instanceof Chosen
        $this.data('chosen', new Chosen(this, options))

      return

})

class Chosen extends AbstractChosen

  setup: ->
    @form_field_jq = $ @form_field
    @current_selectedIndex = @form_field.selectedIndex
    @is_rtl = @form_field_jq.hasClass "chosen-rtl"

  set_up_html: ->
    container_classes = ["chosen-container"]
    container_classes.push "chosen-container-" + (if @is_multiple then "multi" else "single")
    container_classes.push @form_field.className if @inherit_select_classes && @form_field.className
    container_classes.push "chosen-rtl" if @is_rtl

    container_props =
      'class': container_classes.join ' '
      'style': "width: #{this.container_width()};"
      'title': @form_field.title

    container_props.id = @form_field.id.replace(/[^\w]/g, '_') + "_chosen" if @form_field.id.length

    @container = ($ "<div />", container_props)

    if @is_multiple
      @container.html '<ul class="chosen-choices"><li class="search-field"><input type="text" value="' + @default_text + '" class="default" autocomplete="off" style="width:25px;" /></li></ul><div class="chosen-drop"><ul class="chosen-results"></ul></div>'
    else
      @container.html '<a class="chosen-single chosen-default" tabindex="-1"><span>' + @default_text + '</span><div><b></b></div></a><div class="chosen-drop"><div class="chosen-search"><input type="text" autocomplete="off" /></div><ul class="chosen-results"></ul></div>'

    @form_field_jq.hide().after @container
    @dropdown = @container.find('div.chosen-drop').first()

    @search_field = @container.find('input').first()
    @search_results = @container.find('ul.chosen-results').first()
    this.search_field_scale()

    @search_no_results = @container.find('li.no-results').first()

    if @is_multiple
      @search_choices = @container.find('ul.chosen-choices').first()
      @search_container = @container.find('li.search-field').first()
    else
      @search_container = @container.find('div.chosen-search').first()
      @selected_item = @container.find('.chosen-single').first()

    this.results_build()
    this.set_tab_index()
    this.set_label_behavior()
    @form_field_jq.trigger("chosen:ready", {chosen: this})

  register_observers: ->
    @container.bind 'touchstart.chosen', (evt) => this.container_mousedown(evt); return
    @container.bind 'touchend.chosen', (evt) => this.container_mouseup(evt); return

    @container.bind 'mousedown.chosen', (evt) => this.container_mousedown(evt); return
    @container.bind 'mouseup.chosen', (evt) => this.container_mouseup(evt); return
    @container.bind 'mouseenter.chosen', (evt) => this.mouse_enter(evt); return
    @container.bind 'mouseleave.chosen', (evt) => this.mouse_leave(evt); return

    @search_results.bind 'mouseup.chosen', (evt) => this.search_results_mouseup(evt); return
    @search_results.bind 'mouseover.chosen', (evt) => this.search_results_mouseover(evt); return
    @search_results.bind 'mouseout.chosen', (evt) => this.search_results_mouseout(evt); return
    @search_results.bind 'mousewheel.chosen DOMMouseScroll.chosen', (evt) => this.search_results_mousewheel(evt); return

    @search_results.bind 'touchstart.chosen', (evt) => this.search_results_touchstart(evt); return
    @search_results.bind 'touchmove.chosen', (evt) => this.search_results_touchmove(evt); return
    @search_results.bind 'touchend.chosen', (evt) => this.search_results_touchend(evt); return

    @form_field_jq.bind "chosen:updated.chosen", (evt) => this.results_update_field(evt); return
    @form_field_jq.bind "chosen:activate.chosen", (evt) => this.activate_field(evt); return
    @form_field_jq.bind "chosen:open.chosen", (evt) => this.container_mousedown(evt); return
    @form_field_jq.bind "chosen:close.chosen", (evt) => this.input_blur(evt); return

    @search_field.bind 'blur.chosen', (evt) => this.input_blur(evt); return
    @search_field.bind 'keyup.chosen', (evt) => this.keyup_checker(evt); return
    @search_field.bind 'keydown.chosen', (evt) => this.keydown_checker(evt); return
    @search_field.bind 'focus.chosen', (evt) => this.input_focus(evt); return
    @search_field.bind 'cut.chosen', (evt) => this.clipboard_event_checker(evt); return
    @search_field.bind 'paste.chosen', (evt) => this.clipboard_event_checker(evt); return

    if @is_multiple
      @search_choices.bind 'click.chosen', (evt) => this.choices_click(evt); return
    else
      @container.bind 'click.chosen', (evt) -> evt.preventDefault(); return # gobble click of anchor

  destroy: ->
    $(@container[0].ownerDocument).unbind "click.chosen", @click_test_action
    if @search_field[0].tabIndex
      @form_field_jq[0].tabIndex = @search_field[0].tabIndex

    @container.remove()
    @form_field_jq.removeData('chosen')
    @form_field_jq.show()

  search_field_disabled: ->
    @is_disabled = @form_field_jq[0].disabled
    if(@is_disabled)
      @container.addClass 'chosen-disabled'
      @search_field[0].disabled = true
      @selected_item.unbind "focus.chosen", @activate_action if !@is_multiple
      this.close_field()
    else
      @container.removeClass 'chosen-disabled'
      @search_field[0].disabled = false
      @selected_item.bind "focus.chosen", @activate_action if !@is_multiple

  container_mousedown: (evt) ->
    if !@is_disabled
      if evt and evt.type is "mousedown" and not @results_showing
        evt.preventDefault()

      if not (evt? and ($ evt.target).hasClass "search-choice-close")
        if not @active_field
          @search_field.val "" if @is_multiple
          $(@container[0].ownerDocument).bind 'click.chosen', @click_test_action
          this.results_show()
        else if not @is_multiple and evt and (($(evt.target)[0] == @selected_item[0]) || $(evt.target).parents("a.chosen-single").length)
          evt.preventDefault()
          this.results_toggle()

        this.activate_field()

  container_mouseup: (evt) ->
    this.results_reset(evt) if evt.target.nodeName is "ABBR" and not @is_disabled

  search_results_mousewheel: (evt) ->
    delta = evt.originalEvent.deltaY or -evt.originalEvent.wheelDelta or evt.originalEvent.detail if evt.originalEvent
    if delta?
      evt.preventDefault()
      delta = delta * 40 if evt.type is 'DOMMouseScroll'
      @search_results.scrollTop(delta + @search_results.scrollTop())

  blur_test: (evt) ->
    this.close_field() if not @active_field and @container.hasClass "chosen-container-active"

  close_field: ->
    $(@container[0].ownerDocument).unbind "click.chosen", @click_test_action

    @active_field = false
    this.results_hide()

    @container.removeClass "chosen-container-active"
    this.clear_backstroke()

    this.show_search_field_default()
    this.search_field_scale()

  activate_field: ->
    @container.addClass "chosen-container-active"
    @active_field = true

    @search_field.val(@search_field.val())
    @search_field.focus()


  test_active_click: (evt) ->
    active_container = $(evt.target).closest('.chosen-container')
    if active_container.length and @container[0] == active_container[0]
      @active_field = true
    else
      this.close_field()

  results_build: ->
    @parsing = true
    @selected_option_count = null

    @results_data = SelectParser.select_to_array @form_field

    if @is_multiple
      @search_choices.find("li.search-choice").remove()
    else if not @is_multiple
      this.single_set_selected_text()
      if @disable_search or @form_field.options.length <= @disable_search_threshold and not @create_option
        @search_field[0].readOnly = true
        @container.addClass "chosen-container-single-nosearch"
      else
        @search_field[0].readOnly = false
        @container.removeClass "chosen-container-single-nosearch"

    this.update_results_content this.results_option_build({first:true})

    this.search_field_disabled()
    this.show_search_field_default()
    this.search_field_scale()

    @parsing = false

  result_do_highlight: (el) ->
    if el.length
      this.result_clear_highlight()

      @result_highlight = el
      @result_highlight.addClass "highlighted"

      maxHeight = parseInt @search_results.css("maxHeight"), 10
      visible_top = @search_results.scrollTop()
      visible_bottom = maxHeight + visible_top

      high_top = @result_highlight.position().top + @search_results.scrollTop()
      high_bottom = high_top + @result_highlight.outerHeight()

      if high_bottom >= visible_bottom
        @search_results.scrollTop if (high_bottom - maxHeight) > 0 then (high_bottom - maxHeight) else 0
      else if high_top < visible_top
        @search_results.scrollTop high_top

  result_clear_highlight: ->
    @result_highlight.removeClass "highlighted" if @result_highlight
    @result_highlight = null

  results_show: ->
    if @is_multiple and @max_selected_options <= this.choices_count()
      @form_field_jq.trigger("chosen:maxselected", {chosen: this})
      return false

    @container.addClass "chosen-with-drop"
    @results_showing = true

    @search_field.focus()
    @search_field.val @search_field.val()

    this.winnow_results()
    @form_field_jq.trigger("chosen:showing_dropdown", {chosen: this})

  update_results_content: (content) ->
    @search_results.html content

  results_hide: ->
    if @results_showing
      this.result_clear_highlight()

      @container.removeClass "chosen-with-drop"
      @form_field_jq.trigger("chosen:hiding_dropdown", {chosen: this})

    @results_showing = false


  set_tab_index: (el) ->
    if @form_field.tabIndex
      ti = @form_field.tabIndex
      @form_field.tabIndex = -1
      @search_field[0].tabIndex = ti

  set_label_behavior: ->
    @form_field_label = @form_field_jq.parents("label") # first check for a parent label
    if not @form_field_label.length and @form_field.id.length
      @form_field_label = $("label[for='#{@form_field.id}']") #next check for a for=#{id}

    if @form_field_label.length > 0
      @form_field_label.bind 'click.chosen', (evt) => if @is_multiple then this.container_mousedown(evt) else this.activate_field()

  show_search_field_default: ->
    if @is_multiple and this.choices_count() < 1 and not @active_field
      @search_field.val(@default_text)
      @search_field.addClass "default"
    else
      @search_field.val("")
      @search_field.removeClass "default"

  search_results_mouseup: (evt) ->
    target = if $(evt.target).hasClass "active-result" then $(evt.target) else $(evt.target).parents(".active-result").first()
    if target.length
      @result_highlight = target
      this.result_select(evt)
      @search_field.focus()

  search_results_mouseover: (evt) ->
    target = if $(evt.target).hasClass "active-result" then $(evt.target) else $(evt.target).parents(".active-result").first()
    this.result_do_highlight( target ) if target

  search_results_mouseout: (evt) ->
    this.result_clear_highlight() if $(evt.target).hasClass "active-result" or $(evt.target).parents('.active-result').first()

  choice_build: (item) ->
    choice = $('<li />', { class: "search-choice" }).html("<span>#{item.html}</span>")

    if item.disabled
      choice.addClass 'search-choice-disabled'
    else
      close_link = $('<a />', { class: 'search-choice-close', 'data-option-array-index': item.array_index })
      close_link.bind 'click.chosen', (evt) => this.choice_destroy_link_click(evt)
      choice.append close_link

    @search_container.before  choice

  choice_destroy_link_click: (evt) ->
    evt.preventDefault()
    evt.stopPropagation()
    this.choice_destroy $(evt.target) unless @is_disabled

  choice_destroy: (link) ->
    if this.result_deselect( link[0].getAttribute("data-option-array-index") )
      this.show_search_field_default()

      this.results_hide() if @is_multiple and this.choices_count() > 0 and @search_field.val().length < 1

      link.parents('li').first().remove()

      this.search_field_scale()

  results_reset: ->
    this.reset_single_select_options()
    @form_field.options[0].selected = true
    this.single_set_selected_text()
    this.show_search_field_default()
    this.results_reset_cleanup()
    @form_field_jq.trigger "change"
    this.results_hide() if @active_field

  results_reset_cleanup: ->
    @current_selectedIndex = @form_field.selectedIndex
    @selected_item.find("abbr").remove()

  result_select: (evt) ->
    if @result_highlight
      high = @result_highlight

      if high.hasClass "create-option"
        this.select_create_option(@search_field.val())
        return this.results_hide()

      this.result_clear_highlight()

      if @is_multiple and @max_selected_options <= this.choices_count()
        @form_field_jq.trigger("chosen:maxselected", {chosen: this})
        return false

      if @is_multiple
        high.removeClass("active-result")
      else
        this.reset_single_select_options()

      item = @results_data[ high[0].getAttribute("data-option-array-index") ]
      item.selected = true

      @form_field.options[item.options_index].selected = true
      @selected_option_count = null

      if @is_multiple
        this.choice_build item
      else
        this.single_set_selected_text(item.text)

      this.results_hide() unless (evt.metaKey or evt.ctrlKey) and @is_multiple

      @search_field.val ""

      @form_field_jq.trigger "change", {'selected': @form_field.options[item.options_index].value} if @is_multiple || @form_field.selectedIndex != @current_selectedIndex
      @current_selectedIndex = @form_field.selectedIndex
      this.search_field_scale()

  single_set_selected_text: (text=@default_text) ->
    if text is @default_text
      @selected_item.addClass("chosen-default")
    else
      this.single_deselect_control_build()
      @selected_item.removeClass("chosen-default")

    @selected_item.find("span").text(text)

  result_deselect: (pos) ->
    result_data = @results_data[pos]

    if not @form_field.options[result_data.options_index].disabled
      result_data.selected = false

      @form_field.options[result_data.options_index].selected = false
      @selected_option_count = null

      this.result_clear_highlight()
      this.winnow_results() if @results_showing

      @form_field_jq.trigger "change", {deselected: @form_field.options[result_data.options_index].value}
      this.search_field_scale()

      return true
    else
      return false

  single_deselect_control_build: ->
    return unless @allow_single_deselect
    @selected_item.find("span").first().after "<abbr class=\"search-choice-close\"></abbr>" unless @selected_item.find("abbr").length
    @selected_item.addClass("chosen-single-with-deselect")

  get_search_text: ->
    if @search_field.val() is @default_text then "" else $('<div/>').text($.trim(@search_field.val())).html()

  winnow_results_set_highlight: ->
    selected_results = if not @is_multiple then @search_results.find(".result-selected.active-result") else []
    do_high = if selected_results.length then selected_results.first() else @search_results.find(".active-result").first()

    this.result_do_highlight do_high if do_high?

  no_results: (terms) ->
    no_results_html = $('<li class="no-results">' + @results_none_found + ' "<span></span>"</li>')
    no_results_html.find("span").first().html(terms)
    @search_results.append no_results_html
    @form_field_jq.trigger("chosen:no_results", {chosen:this})

  show_create_option: (terms) ->
    create_option_html = $('<li class="create-option active-result"><a>' + @create_option_text + '</a>: "' + terms + '"</li>')
    @search_results.append create_option_html

  create_option_clear: ->
    @search_results.find(".create-option").remove()

  select_create_option: (terms) ->
    if $.isFunction(@create_option)
      @create_option.call this, terms
    else
      this.select_append_option( {value: terms, text: terms} )

  select_append_option: ( options ) ->
    option = $('<option />', options ).attr('selected', 'selected')
    @form_field_jq.append option
    @form_field_jq.trigger "chosen:updated"
    @form_field_jq.trigger "change"
    @search_field.trigger "focus"

  no_results_clear: ->
    @search_results.find(".no-results").remove()

  keydown_arrow: ->
    if @results_showing and @result_highlight
      next_sib = @result_highlight.nextAll("li.active-result").first()
      this.result_do_highlight next_sib if next_sib
    else if @results_showing and @create_option
      this.result_do_highlight(@search_results.find('.create-option'))
    else
      this.results_show()

  keyup_arrow: ->
    if not @results_showing and not @is_multiple
      this.results_show()
    else if @result_highlight
      prev_sibs = @result_highlight.prevAll("li.active-result")

      if prev_sibs.length
        this.result_do_highlight prev_sibs.first()
      else
        this.results_hide() if this.choices_count() > 0
        this.result_clear_highlight()

  keydown_backstroke: ->
    if @pending_backstroke
      this.choice_destroy @pending_backstroke.find("a").first()
      this.clear_backstroke()
    else
      next_available_destroy = @search_container.siblings("li.search-choice").last()
      if next_available_destroy.length and not next_available_destroy.hasClass("search-choice-disabled")
        @pending_backstroke = next_available_destroy
        if @single_backstroke_delete
          @keydown_backstroke()
        else
          @pending_backstroke.addClass "search-choice-focus"

  clear_backstroke: ->
    @pending_backstroke.removeClass "search-choice-focus" if @pending_backstroke
    @pending_backstroke = null

  keydown_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    this.clear_backstroke() if stroke != 8 and this.pending_backstroke

    switch stroke
      when 8
        @backstroke_length = this.search_field.val().length
        break
      when 9
        this.result_select(evt) if this.results_showing and not @is_multiple
        @mouse_on_container = false
        break
      when 13
        evt.preventDefault() if this.results_showing
        break
      when 38
        evt.preventDefault()
        this.keyup_arrow()
        break
      when 40
        evt.preventDefault()
        this.keydown_arrow()
        break

  search_field_scale: ->
    if @is_multiple
      h = 0
      w = 0

      style_block = "position:absolute; left: -1000px; top: -1000px; display:none;"
      styles = ['font-size','font-style', 'font-weight', 'font-family','line-height', 'text-transform', 'letter-spacing']

      for style in styles
        style_block += style + ":" + @search_field.css(style) + ";"

      div = $('<div />', { 'style' : style_block })
      div.text @search_field.val()
      $('body').append div

      w = div.width() + 25
      div.remove()

      f_width = @container.outerWidth()

      if( w > f_width - 10 )
        w = f_width - 10

      @search_field.css({'width': w + 'px'})

