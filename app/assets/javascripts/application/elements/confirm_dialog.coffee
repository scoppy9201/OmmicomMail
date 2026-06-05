renderMessage = ($container, message) ->
  $container.empty()
  lines = String(message || '').split(/\r?\n/)
  for line in lines
    cleanLine = $.trim(line)
    if cleanLine.length
      $('<p />').text(cleanLine).appendTo($container)

ensureConfirmDialog = ->
  $dialog = $('.js-confirmDialog')
  return $dialog if $dialog.length

  $dialog = $("""
    <div class="confirmDialog js-confirmDialog is-hidden" role="dialog" aria-modal="true" aria-labelledby="confirmDialogTitle">
      <div class="confirmDialog__backdrop js-confirmDialog-cancel"></div>
      <div class="confirmDialog__panel">
        <div class="confirmDialog__icon">!</div>
        <div class="confirmDialog__content">
          <h2 class="confirmDialog__title" id="confirmDialogTitle"></h2>
          <div class="confirmDialog__message"></div>
        </div>
        <div class="confirmDialog__actions">
          <button type="button" class="button button--neutral confirmDialog__button js-confirmDialog-cancel js-confirmDialog-cancelButton">Hủy</button>
          <button type="button" class="button button--positive confirmDialog__button js-confirmDialog-confirm">Xác nhận</button>
        </div>
      </div>
    </div>
  """)
  $('body').append($dialog)
  $dialog

closeConfirmDialog = ->
  $('.js-confirmDialog').addClass('is-hidden')
  $('html').removeClass('has-confirmDialog')
  $(document).off('keydown.confirmDialog')

openConfirmDialog = (options = {}) ->
  $dialog = ensureConfirmDialog()
  title = options.title || 'Xác nhận thao tác'
  message = options.message || ''
  confirmText = options.confirmText || 'Xác nhận'
  cancelText = options.cancelText || 'Hủy'
  mode = options.mode || 'confirm'

  $('.confirmDialog__title', $dialog).text(title)
  renderMessage($('.confirmDialog__message', $dialog), message)
  $('.js-confirmDialog-confirm', $dialog).text(confirmText)
  $('.js-confirmDialog-cancelButton', $dialog).text(cancelText)
  $('.confirmDialog__icon', $dialog).text(if mode == 'alert' then 'i' else '!')

  if mode == 'alert'
    $dialog.addClass('confirmDialog--alert')
    $('.js-confirmDialog-cancelButton', $dialog).hide()
  else
    $dialog.removeClass('confirmDialog--alert')
    $('.js-confirmDialog-cancelButton', $dialog).show()

  $dialog.removeClass('is-hidden')
  $('html').addClass('has-confirmDialog')
  $('.js-confirmDialog-confirm', $dialog).focus()

  $('.js-confirmDialog-confirm', $dialog).off('click.confirmDialog').on 'click.confirmDialog', ->
    closeConfirmDialog()
    options.onConfirm?()
    false

  $('.js-confirmDialog-cancel', $dialog).off('click.confirmDialog').on 'click.confirmDialog', ->
    closeConfirmDialog()
    options.onCancel?()
    false

  $(document).off('keydown.confirmDialog').on 'keydown.confirmDialog', (event) ->
    if event.keyCode == 27
      closeConfirmDialog()
      options.onCancel?()
    if event.keyCode == 13
      closeConfirmDialog()
      options.onConfirm?()

window.OmmicomMailDialog =
  confirm: (message, options = {}) ->
    options.message = message
    options.mode = 'confirm'
    options.title ||= 'Xác nhận thao tác'
    options.confirmText ||= 'Đồng ý'
    options.cancelText ||= 'Hủy'
    openConfirmDialog(options)

  alert: (message, options = {}) ->
    options.message = message
    options.mode = 'alert'
    options.title ||= 'Thông báo'
    options.confirmText ||= 'Đã hiểu'
    openConfirmDialog(options)

$ ->
  return unless $.rails

  $.rails.allowAction = (element) ->
    message = element.data('confirm')
    return true unless message

    if element.data('confirm-dialog-confirmed')
      element.removeData('confirm-dialog-confirmed')
      return true

    return false unless $.rails.fire(element, 'confirm')

    window.OmmicomMailDialog.confirm message,
      onConfirm: ->
        return unless $.rails.fire(element, 'confirm:complete', [true])
        element.data('confirm-dialog-confirmed', true)
        if element.is('form')
          element.trigger('submit')
        else
          element.trigger('click')
      onCancel: ->
        $.rails.fire(element, 'confirm:complete', [false])

    false
