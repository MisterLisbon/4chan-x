ReplyPruning =
  init: ->
    return unless g.VIEW is 'thread' and Conf['Reply Pruning']

    @active = not (Conf['Quote Threading'] and Conf['Thread Quotes'])

    @container = $.frag()

    @summary = $.el 'span',
      hidden:    true
      className: 'summary'
    @summary.style.cursor = 'pointer'
    $.on @summary, 'click', =>
      @inputs.enabled.checked = !@inputs.enabled.checked
      $.event 'change', null, @inputs.enabled

    label = UI.checkbox 'Prune Replies', 'Show Last', @active
    el = $.el 'span',
      title: 'Maximum number of replies to show.'
    ,
      <%= html(' <input type="number" name="Max Replies" min="0" step="1" value="${Conf["Max Replies"]}" class="field">') %>
    $.prepend el, label

    @inputs =
      enabled: label.firstElementChild
      replies: el.lastElementChild

    $.on @inputs.enabled, 'change', @setEnabled
    $.on @inputs.replies, 'change', $.cb.value

    Header.menu.addEntry
      el:    el
      order: 190

    Callbacks.Thread.push
      name: 'Reply Pruning'
      cb:   @node

  position: 0
  hidden: 0
  hiddenFiles: 0
  total: 0
  totalFiles: 0

  setEnabled: ->
    other = QuoteThreading.input
    if @checked and other?.checked
      other.checked = false
      $.event 'change', null, other
    ReplyPruning.active = @checked

  showIfHidden: (id) ->
    if ReplyPruning.container?.getElementById id
      ReplyPruning.inputs.enabled.checked = false
      $.event 'change', null, ReplyPruning.inputs.enabled

  node: ->
    ReplyPruning.thread = @

    @posts.forEach (post) ->
      if post.isReply
        ReplyPruning.total++
        ReplyPruning.totalFiles++ if post.file

    # If we're linked to a post that we would hide, don't hide the posts in the first place.
    # Also don't hide posts if we open the thread by a link to the OP.
    if (
      ReplyPruning.active and
      /^#p\d+$/.test(location.hash) and
      0 <= @posts.keys.indexOf(location.hash[2..]) < 1 + Math.max(ReplyPruning.total - +Conf["Max Replies"], 0)
    )
      ReplyPruning.active = ReplyPruning.inputs.enabled.checked = false

    $.after @OP.nodes.root, ReplyPruning.summary

    $.on ReplyPruning.inputs.enabled, 'change', ReplyPruning.update
    $.on ReplyPruning.inputs.replies, 'change', ReplyPruning.update
    $.on d, 'ThreadUpdate', ReplyPruning.updateCount
    $.on d, 'ThreadUpdate', ReplyPruning.update

    ReplyPruning.update()

  updateCount: (e) ->
    return if e.detail[404]
    for fullID in e.detail.newPosts
      ReplyPruning.total++
      ReplyPruning.totalFiles++ if g.posts[fullID].file
    return

  update: ->
    hidden2 = if ReplyPruning.active
      Math.max(ReplyPruning.total - +Conf["Max Replies"], 0)
    else
      0

    # Record position from bottom of document
    oldPos = d.body.clientHeight - window.scrollY

    {posts} = ReplyPruning.thread

    if ReplyPruning.hidden < hidden2
      while ReplyPruning.hidden < hidden2 and ReplyPruning.position < posts.keys.length
        post = posts[posts.keys[ReplyPruning.position++]]
        if post.isReply and not post.isFetchedQuote
          $.add ReplyPruning.container, post.nodes.root
          ReplyPruning.hidden++
          ReplyPruning.hiddenFiles++ if post.file

    else if ReplyPruning.hidden > hidden2
      frag = $.frag()
      while ReplyPruning.hidden > hidden2 and ReplyPruning.position > 0
        post = posts[posts.keys[--ReplyPruning.position]]
        if post.isReply and not post.isFetchedQuote
          $.prepend frag, post.nodes.root
          ReplyPruning.hidden--
          ReplyPruning.hiddenFiles-- if post.file
      $.after ReplyPruning.summary, frag
      $.event 'PostsInserted'

    ReplyPruning.summary.textContent = if ReplyPruning.active
      Build.summaryText '+', ReplyPruning.hidden, ReplyPruning.hiddenFiles
    else
      Build.summaryText '-', ReplyPruning.total, ReplyPruning.totalFiles
    ReplyPruning.summary.hidden = (ReplyPruning.total <= +Conf["Max Replies"])

    # Maintain position in thread when posts are added/removed above
    if (boardTop = Header.getTopOf $('.board')) < 0
      window.scroll window.scrollX, Math.max(d.body.clientHeight - oldPos, window.scrollY + boardTop)

return ReplyPruning
