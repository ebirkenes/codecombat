ModalView = require 'views/kinds/ModalView'
template = require 'templates/play/modal/play-achievements-modal'
CocoCollection = require 'collections/CocoCollection'
Achievement = require 'models/Achievement'
EarnedAchievement = require 'models/EarnedAchievement'

utils = require 'lib/utils'

PAGE_SIZE = 200

module.exports = class PlayAchievementsModal extends ModalView
  className: 'modal fade play-modal'
  template: template
  id: 'play-achievements-modal'
  plain: true

  earnedMap: {}

  constructor: (options) ->
    super options
    @achievements = new Backbone.Collection()
    earnedMap = {}

    achievementsFetcher = new CocoCollection([], {url: '/db/achievement', model: Achievement})
    achievementsFetcher.setProjection([
      'name'
      'description'
      'icon'
      'worth'
      'i18n'
      'rewards'
      'collection'
    ])

    earnedAchievementsFetcher = new CocoCollection([], {url: '/db/earned_achievement', model: EarnedAchievement})
    earnedAchievementsFetcher.setProjection([ 'achievement' ])

    achievementsFetcher.skip = 0
    achievementsFetcher.fetch({data: {skip: 0, limit: PAGE_SIZE}})
    earnedAchievementsFetcher.skip = 0
    earnedAchievementsFetcher.fetch({data: {skip: 0, limit: PAGE_SIZE}})

    @listenTo achievementsFetcher, 'sync', @onAchievementsLoaded
    @listenTo earnedAchievementsFetcher, 'sync', @onEarnedAchievementsLoaded

    @supermodel.loadCollection(achievementsFetcher, 'achievement')
    @supermodel.loadCollection(earnedAchievementsFetcher, 'achievement')

    @onEverythingLoaded = _.after(2, @onEverythingLoaded)

  onAchievementsLoaded: (fetcher) ->
    needMore = fetcher.models.length is PAGE_SIZE
    @achievements.add(fetcher.models)
    if needMore
      fetcher.skip += PAGE_SIZE
      fetcher.fetch({data: {skip: fetcher.skip, limit: PAGE_SIZE}})
    else
      @stopListening(fetcher)
      @onEverythingLoaded()

  onEarnedAchievementsLoaded: (fetcher) ->
    needMore = fetcher.models.length is PAGE_SIZE
    for earned in fetcher.models
      @earnedMap[earned.get('achievement')] = earned
    if needMore
      fetcher.skip += PAGE_SIZE
      fetcher.fetch({data: {skip: fetcher.skip, limit: PAGE_SIZE}})
    else
      @stopListening(fetcher)
      @onEverythingLoaded()

  onEverythingLoaded: =>
    @achievements.set(@achievements.filter((m) -> m.get('collection') isnt 'level.sessions'))
    for achievement in @achievements.models
      if earned = @earnedMap[achievement.id]
        achievement.earned = earned
        achievement.earnedDate = earned.getCreationDate()
      achievement.earnedDate ?= ''
    @achievements.comparator = (m) -> m.earnedDate
    @achievements.sort()
    @achievements.set(@achievements.models.reverse())
    for achievement in @achievements.models
      achievement.name = utils.i18n achievement.attributes, 'name'
      achievement.description = utils.i18n achievement.attributes, 'description'
    @render()

  getRenderData: (context={}) ->
    context = super(context)
    context.achievements = @achievements.models
    context

  afterRender: ->
    super()
    return unless @supermodel.finished()
    @playSound 'game-menu-open'

  onHidden: ->
    super()
    @playSound 'game-menu-close'
