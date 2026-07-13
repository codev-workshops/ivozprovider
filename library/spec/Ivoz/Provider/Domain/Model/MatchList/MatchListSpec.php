<?php

namespace spec\Ivoz\Provider\Domain\Model\MatchList;

use Ivoz\Provider\Domain\Model\Company\CompanyDto;
use Ivoz\Provider\Domain\Model\Company\CompanyInterface;
use Ivoz\Provider\Domain\Model\MatchList\MatchList;
use Ivoz\Provider\Domain\Model\MatchList\MatchListDto;
use Ivoz\Provider\Domain\Model\MatchListPattern\MatchListPatternInterface;
use PhpSpec\ObjectBehavior;
use spec\DtoToEntityFakeTransformer;
use spec\HelperTrait;

class MatchListSpec extends ObjectBehavior
{
    use HelperTrait;

    /** @var MatchListDto */
    protected $dto;

    /** @var DtoToEntityFakeTransformer */
    private $transformer;

    public function let(): void
    {
        $company = $this->getTestDouble(CompanyInterface::class);
        $company->getType()->willReturn(CompanyInterface::TYPE_VPBX);

        $companyDto = new CompanyDto();

        $this->dto = $dto = new MatchListDto();
        $dto->setName('matchList')
            ->setCompany($companyDto);

        $this->transformer = new DtoToEntityFakeTransformer([
            [$companyDto, $company->reveal()],
        ]);

        $this->beConstructedThrough('fromDto', [$dto, $this->transformer]);
    }

    public function it_is_initializable(): void
    {
        $this->shouldHaveType(MatchList::class);
    }

    public function it_does_not_match_when_no_patterns_are_set(): void
    {
        $this->numberMatches('+34123456789')->shouldReturn(false);
    }

    public function it_matches_an_exact_number_pattern(): void
    {
        $pattern = $this->getTestDouble(MatchListPatternInterface::class);
        $pattern->getType()->willReturn('number');
        $pattern->getNumberE164()->willReturn('+34123456789');

        $this->addPattern($pattern->reveal());

        $this->numberMatches('+34123456789')->shouldReturn(true);
        $this->numberMatches('+34000000000')->shouldReturn(false);
    }

    public function it_matches_a_regexp_pattern(): void
    {
        $pattern = $this->getTestDouble(MatchListPatternInterface::class);
        $pattern->getType()->willReturn('regexp');
        $pattern->getRegexp()->willReturn('^\+34');

        $this->addPattern($pattern->reveal());

        $this->numberMatches('+34123456789')->shouldReturn(true);
        $this->numberMatches('+44123456789')->shouldReturn(false);
    }

    public function it_rejects_companies_that_are_not_vpbx_or_residential(): void
    {
        $company = $this->getTestDouble(CompanyInterface::class);
        $company->getType()->willReturn(CompanyInterface::TYPE_WHOLESALE);

        $companyDto = new CompanyDto();

        $dto = new MatchListDto();
        $dto->setName('matchList')
            ->setCompany($companyDto);

        $transformer = new DtoToEntityFakeTransformer([
            [$companyDto, $company->reveal()],
        ]);

        $this->beConstructedThrough('fromDto', [$dto, $transformer]);

        $this->shouldThrow(\DomainException::class)->duringInstantiation();
    }
}
