<?php

namespace spec\Ivoz\Provider\Domain\Model\ConditionalRoutesCondition;

use Ivoz\Provider\Domain\Model\Calendar\CalendarInterface;
use Ivoz\Provider\Domain\Model\Company\CompanyInterface;
use Ivoz\Provider\Domain\Model\ConditionalRoute\ConditionalRouteDto;
use Ivoz\Provider\Domain\Model\ConditionalRoute\ConditionalRouteInterface;
use Ivoz\Provider\Domain\Model\ConditionalRoutesCondition\ConditionalRoutesCondition;
use Ivoz\Provider\Domain\Model\ConditionalRoutesCondition\ConditionalRoutesConditionDto;
use Ivoz\Provider\Domain\Model\ConditionalRoutesConditionsRelCalendar\ConditionalRoutesConditionsRelCalendarInterface;
use Ivoz\Provider\Domain\Model\ConditionalRoutesConditionsRelMatchlist\ConditionalRoutesConditionsRelMatchlistInterface;
use Ivoz\Provider\Domain\Model\ConditionalRoutesConditionsRelRouteLock\ConditionalRoutesConditionsRelRouteLockInterface;
use Ivoz\Provider\Domain\Model\ConditionalRoutesConditionsRelSchedule\ConditionalRoutesConditionsRelScheduleInterface;
use Ivoz\Provider\Domain\Model\Country\CountryDto;
use Ivoz\Provider\Domain\Model\Country\CountryInterface;
use Ivoz\Provider\Domain\Model\MatchList\MatchListInterface;
use Ivoz\Provider\Domain\Model\RouteLock\RouteLockInterface;
use Ivoz\Provider\Domain\Model\Schedule\ScheduleInterface;
use Ivoz\Provider\Domain\Model\Timezone\TimezoneInterface;
use PhpSpec\ObjectBehavior;
use Prophecy\Argument;
use spec\DtoToEntityFakeTransformer;
use spec\HelperTrait;

class ConditionalRoutesConditionSpec extends ObjectBehavior
{
    use HelperTrait;

    /** @var ConditionalRoutesConditionDto */
    protected $dto;

    /** @var DtoToEntityFakeTransformer */
    private $transformer;

    /** @var ConditionalRouteInterface */
    private $conditionalRoute;

    public function let(): void
    {
        $timezone = $this->getTestDouble(TimezoneInterface::class);
        $timezone->getTz()->willReturn('UTC');

        $company = $this->getTestDouble(CompanyInterface::class);
        $company->getDefaultTimezone()->willReturn($timezone->reveal());

        $this->conditionalRoute = $this->getTestDouble(ConditionalRouteInterface::class);
        $this->conditionalRoute->getCompany()->willReturn($company->reveal());

        $conditionalRouteDto = new ConditionalRouteDto();

        $this->dto = $dto = new ConditionalRoutesConditionDto();
        $dto->setPriority(1)
            ->setConditionalRoute($conditionalRouteDto);

        $this->transformer = new DtoToEntityFakeTransformer([
            [$conditionalRouteDto, $this->conditionalRoute->reveal()],
        ]);

        $this->beConstructedThrough('fromDto', [$dto, $this->transformer]);
    }

    public function it_is_initializable(): void
    {
        $this->shouldHaveType(ConditionalRoutesCondition::class);
    }

    public function it_returns_the_related_match_lists(): void
    {
        $matchList = $this->getTestDouble(MatchListInterface::class)->reveal();
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelMatchlistInterface::class);
        $rel->getMatchlist()->willReturn($matchList);

        $this->addRelMatchlist($rel->reveal());

        $this->getMatchLists()->shouldReturn([$matchList]);
    }

    public function it_returns_the_related_schedules(): void
    {
        $schedule = $this->getTestDouble(ScheduleInterface::class)->reveal();
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelScheduleInterface::class);
        $rel->getSchedule()->willReturn($schedule);

        $this->addRelSchedule($rel->reveal());

        $this->getSchedules()->shouldReturn([$schedule]);
    }

    public function it_returns_the_related_calendars(): void
    {
        $calendar = $this->getTestDouble(CalendarInterface::class)->reveal();
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelCalendarInterface::class);
        $rel->getCalendar()->willReturn($calendar);

        $this->addRelCalendar($rel->reveal());

        $this->getCalendars()->shouldReturn([$calendar]);
    }

    public function it_returns_the_related_route_locks(): void
    {
        $routeLock = $this->getTestDouble(RouteLockInterface::class)->reveal();
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelRouteLockInterface::class);
        $rel->getRouteLock()->willReturn($routeLock);

        $this->addRelRouteLock($rel->reveal());

        $this->getRouteLocks()->shouldReturn([$routeLock]);
    }

    public function it_matches_origin_when_no_match_lists_are_set(): void
    {
        $this->matchesOrigin('+34123456789')->shouldReturn(true);
    }

    public function it_matches_origin_when_a_match_list_matches(): void
    {
        $matchList = $this->getTestDouble(MatchListInterface::class);
        $matchList->numberMatches('+34123456789')->willReturn(true);
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelMatchlistInterface::class);
        $rel->getMatchlist()->willReturn($matchList->reveal());

        $this->addRelMatchlist($rel->reveal());

        $this->matchesOrigin('+34123456789')->shouldReturn(true);
    }

    public function it_does_not_match_origin_when_no_match_list_matches(): void
    {
        $matchList = $this->getTestDouble(MatchListInterface::class);
        $matchList->numberMatches('+34123456789')->willReturn(false);
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelMatchlistInterface::class);
        $rel->getMatchlist()->willReturn($matchList->reveal());

        $this->addRelMatchlist($rel->reveal());

        $this->matchesOrigin('+34123456789')->shouldReturn(false);
    }

    public function it_matches_route_lock_when_none_are_set(): void
    {
        $this->matchesRouteLock()->shouldReturn(true);
    }

    public function it_matches_route_lock_when_a_lock_is_open(): void
    {
        $routeLock = $this->getTestDouble(RouteLockInterface::class);
        $routeLock->isOpen()->willReturn(true);
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelRouteLockInterface::class);
        $rel->getRouteLock()->willReturn($routeLock->reveal());

        $this->addRelRouteLock($rel->reveal());

        $this->matchesRouteLock()->shouldReturn(true);
    }

    public function it_does_not_match_route_lock_when_all_locks_are_closed(): void
    {
        $routeLock = $this->getTestDouble(RouteLockInterface::class);
        $routeLock->isOpen()->willReturn(false);
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelRouteLockInterface::class);
        $rel->getRouteLock()->willReturn($routeLock->reveal());

        $this->addRelRouteLock($rel->reveal());

        $this->matchesRouteLock()->shouldReturn(false);
    }

    public function it_matches_schedule_when_none_are_set(): void
    {
        $this->matchesSchedule()->shouldReturn(true);
    }

    public function it_matches_schedule_against_company_timezone(): void
    {
        $schedule = $this->getTestDouble(ScheduleInterface::class);
        $schedule->isOnSchedule(Argument::type(\DateTimeInterface::class))->willReturn(true);
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelScheduleInterface::class);
        $rel->getSchedule()->willReturn($schedule->reveal());

        $this->addRelSchedule($rel->reveal());

        $this->matchesSchedule()->shouldReturn(true);
    }

    public function it_matches_calendar_when_none_are_set(): void
    {
        $this->matchesCalendar()->shouldReturn(true);
    }

    public function it_matches_calendar_against_company_timezone(): void
    {
        $calendar = $this->getTestDouble(CalendarInterface::class);
        $calendar->isHolidayDate(Argument::type(\DateTimeInterface::class))->willReturn(true);
        $rel = $this->getTestDouble(ConditionalRoutesConditionsRelCalendarInterface::class);
        $rel->getCalendar()->willReturn($calendar->reveal());

        $this->addRelCalendar($rel->reveal());

        $this->matchesCalendar()->shouldReturn(true);
    }

    public function it_builds_a_match_data_string(): void
    {
        $matchList = $this->getTestDouble(MatchListInterface::class);
        $matchList->getName()->willReturn('matchList');
        $matchListRel = $this->getTestDouble(ConditionalRoutesConditionsRelMatchlistInterface::class);
        $matchListRel->getMatchlist()->willReturn($matchList->reveal());
        $this->addRelMatchlist($matchListRel->reveal());

        $schedule = $this->getTestDouble(ScheduleInterface::class);
        $schedule->getName()->willReturn('schedule');
        $scheduleRel = $this->getTestDouble(ConditionalRoutesConditionsRelScheduleInterface::class);
        $scheduleRel->getSchedule()->willReturn($schedule->reveal());
        $this->addRelSchedule($scheduleRel->reveal());

        $this->getMatchData()->shouldReturn('matchList,schedule');
    }

    public function it_returns_empty_e164_number_without_country(): void
    {
        $this->getNumberValueE164()->shouldReturn('');
    }

    public function it_builds_the_e164_number_with_country(): void
    {
        $country = $this->getTestDouble(CountryInterface::class);
        $country->getCountryCode()->willReturn('+34');
        $countryDto = new CountryDto();
        $conditionalRouteDto = new ConditionalRouteDto();

        $dto = new ConditionalRoutesConditionDto();
        $dto->setPriority(1)
            ->setConditionalRoute($conditionalRouteDto)
            ->setRouteType('number')
            ->setNumberValue('123456789')
            ->setNumberCountry($countryDto);

        $transformer = new DtoToEntityFakeTransformer([
            [$conditionalRouteDto, $this->conditionalRoute->reveal()],
            [$countryDto, $country->reveal()],
        ]);

        $this->beConstructedThrough('fromDto', [$dto, $transformer]);

        $this->getNumberValueE164()->shouldReturn('+34123456789');
    }
}
