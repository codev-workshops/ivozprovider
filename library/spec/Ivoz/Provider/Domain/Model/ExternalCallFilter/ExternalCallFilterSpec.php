<?php

namespace spec\Ivoz\Provider\Domain\Model\ExternalCallFilter;

use Ivoz\Provider\Domain\Model\Company\Company;
use Ivoz\Provider\Domain\Model\Company\CompanyDto;
use Ivoz\Provider\Domain\Model\Country\CountryDto;
use Ivoz\Provider\Domain\Model\Country\CountryInterface;
use Ivoz\Provider\Domain\Model\Extension\Extension;
use Ivoz\Provider\Domain\Model\Extension\ExtensionDto;
use Ivoz\Provider\Domain\Model\ExternalCallFilter\ExternalCallFilter;
use Ivoz\Provider\Domain\Model\ExternalCallFilter\ExternalCallFilterDto;
use Ivoz\Provider\Domain\Model\ExternalCallFilterBlackList\ExternalCallFilterBlackListInterface;
use Ivoz\Provider\Domain\Model\ExternalCallFilterWhiteList\ExternalCallFilterWhiteListInterface;
use Ivoz\Provider\Domain\Model\MatchList\MatchListInterface;
use Ivoz\Provider\Domain\Model\Voicemail\Voicemail;
use Ivoz\Provider\Domain\Model\Voicemail\VoicemailDto;
use PhpSpec\ObjectBehavior;
use spec\DtoToEntityFakeTransformer;
use spec\HelperTrait;

class ExternalCallFilterSpec extends ObjectBehavior
{
    use HelperTrait;

    /**
     * @var ExternalCallFilterDto
     */
    protected $dto;

    /**
     * @var DtoToEntityFakeTransformer
     */
    protected $transformer;

    function let()
    {
        $companyDto = new CompanyDto();
        $company = $this->getInstance(Company::class);

        $this->dto = $dto = new ExternalCallFilterDto();
        $dto
            ->setName('name')
            ->setCompany($companyDto);

        $this->transformer = new DtoToEntityFakeTransformer([
            [$companyDto, $company]
        ]);

        $this->beConstructedThrough(
            'fromDto',
            [$dto, $this->transformer]
        );
    }

    function it_is_initializable()
    {
        $this->shouldHaveType(ExternalCallFilter::class);
    }

    function it_resets_holiday_targets_but_current_value()
    {
        $holidayVoicemailDto = new VoicemailDto();
        $holidayVoicemail = $this->getInstance(
            Voicemail::class
        );

        $holidayExtensionDto = new ExtensionDto();
        $holidayExtension = $this->getInstance(
            Extension::class
        );

        $this
            ->dto
            ->setHolidayTargetType('number')
            ->setHolidayNumberValue('1234')
            ->setHolidayExtension($holidayExtensionDto)
            ->setHolidayVoicemail($holidayVoicemailDto);

        $this->transformer->appendFixedTransforms([
            [$holidayExtensionDto, $holidayExtension],
            [$holidayVoicemailDto, $holidayVoicemail],
        ]);

        $this
            ->getHolidayExtension()
            ->shouldBe(null);

        $this
            ->getHolidayVoicemail()
            ->shouldBe(null);
    }

    function it_resets_outOfSchedule_targets_but_current_value()
    {
        $outOfSchedulevoicemailDto = new voicemailDto();
        $outOfSchedulevoicemail = $this->getInstance(
            Voicemail::class
        );

        $outOfScheduleExtensionDto = new ExtensionDto();
        $outOfScheduleExtension = $this->getInstance(
            Extension::class
        );

        $this
            ->dto
            ->setHolidayTargetType('number')
            ->setHolidayNumberValue('1234')
            ->setOutOfScheduleExtension($outOfScheduleExtensionDto)
            ->setOutOfSchedulevoicemail($outOfSchedulevoicemailDto);

        $this->transformer->appendFixedTransforms([
            [$outOfScheduleExtensionDto, $outOfScheduleExtension],
            [$outOfSchedulevoicemailDto, $outOfSchedulevoicemail],
        ]);

        $this
            ->getOutOfScheduleExtension()
            ->shouldBe(null);

        $this
            ->getOutOfSchedulevoicemail()
            ->shouldBe(null);
    }

    function it_builds_the_holiday_e164_number_and_target()
    {
        $country = $this->getTestDouble(CountryInterface::class);
        $country->getCountryCode()->willReturn('+34');
        $countryDto = new CountryDto();

        $this->dto
            ->setHolidayEnabled(true)
            ->setHolidayTargetType('number')
            ->setHolidayNumberValue('123456789')
            ->setHolidayNumberCountry($countryDto);

        $this->transformer->appendFixedTransforms([
            [$countryDto, $country->reveal()],
        ]);

        $this->getHolidayNumberValueE164()->shouldReturn('+34123456789');
        $this->getHolidayTarget()->shouldReturn('+34123456789');
        $this->getHolidayRouteType()->shouldReturn('number');
    }

    function it_returns_empty_holiday_e164_number_without_country()
    {
        $this->dto->setHolidayEnabled(true);

        $this->getHolidayNumberValueE164()->shouldReturn('');
    }

    function it_builds_the_out_of_schedule_e164_number_and_target()
    {
        $country = $this->getTestDouble(CountryInterface::class);
        $country->getCountryCode()->willReturn('+34');
        $countryDto = new CountryDto();

        $this->dto
            ->setOutOfScheduleEnabled(true)
            ->setOutOfScheduleTargetType('number')
            ->setOutOfScheduleNumberValue('123456789')
            ->setOutOfScheduleNumberCountry($countryDto);

        $this->transformer->appendFixedTransforms([
            [$countryDto, $country->reveal()],
        ]);

        $this->getOutOfScheduleNumberValueE164()->shouldReturn('+34123456789');
        $this->getOutOfScheduleTarget()->shouldReturn('+34123456789');
        $this->getOutOfScheduleRouteType()->shouldReturn('number');
    }

    function it_is_not_black_listed_without_lists()
    {
        $this->isBlackListed('+34123456789')->shouldReturn(false);
    }

    function it_is_black_listed_when_a_list_matches()
    {
        $matchList = $this->getTestDouble(MatchListInterface::class);
        $matchList->numberMatches('+34123456789')->willReturn(true);
        $blackList = $this->getTestDouble(ExternalCallFilterBlackListInterface::class);
        $blackList->getMatchlist()->willReturn($matchList->reveal());

        $this->addBlackList($blackList->reveal());

        $this->isBlackListed('+34123456789')->shouldReturn(true);
    }

    function it_is_whitelisted_when_a_list_matches()
    {
        $matchList = $this->getTestDouble(MatchListInterface::class);
        $matchList->numberMatches('+34123456789')->willReturn(true);
        $whiteList = $this->getTestDouble(ExternalCallFilterWhiteListInterface::class);
        $whiteList->getMatchlist()->willReturn($matchList->reveal());

        $this->addWhiteList($whiteList->reveal());

        $this->isWhitelisted('+34123456789')->shouldReturn(true);
    }

    function it_is_not_out_of_schedule_when_filtering_is_disabled()
    {
        $this->isOutOfSchedule()->shouldReturn(false);
    }

    function it_is_out_of_schedule_when_enabled_with_a_target_and_no_schedules()
    {
        $country = $this->getTestDouble(CountryInterface::class);
        $country->getCountryCode()->willReturn('+34');
        $countryDto = new CountryDto();

        $this->dto
            ->setOutOfScheduleEnabled(true)
            ->setOutOfScheduleTargetType('number')
            ->setOutOfScheduleNumberValue('123456789')
            ->setOutOfScheduleNumberCountry($countryDto);

        $this->transformer->appendFixedTransforms([
            [$countryDto, $country->reveal()],
        ]);

        $this->isOutOfSchedule()->shouldReturn(true);
    }
}
