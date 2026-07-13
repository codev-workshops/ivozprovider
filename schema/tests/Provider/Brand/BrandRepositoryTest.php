<?php

namespace Tests\Provider\Brand;

use Ivoz\Provider\Domain\Model\Brand\Brand;
use Ivoz\Provider\Domain\Model\Brand\BrandRepository;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Tests\DbIntegrationTestHelperTrait;

class BrandRepositoryTest extends KernelTestCase
{
    use DbIntegrationTestHelperTrait;

    /**
     * @test
     */
    public function test_runner()
    {
        $this->it_finds_one_by_domain();
        $this->it_counts_brands();
        $this->it_finds_latest_brands();
        $this->it_gets_names_indexed_by_id();
    }

    public function it_finds_one_by_domain()
    {
        /** @var BrandRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Brand::class);

        $company = $repository->findOneByDomain('sip.irontec.com');

        $this->assertInstanceOf(
            Brand::class,
            $company
        );
    }

    public function it_counts_brands()
    {
        /** @var BrandRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Brand::class);

        $count = $repository->count([]);

        $this->assertEquals(
            3,
            $count
        );
    }

    public function it_finds_latest_brands()
    {
        /** @var BrandRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Brand::class);

        $brands = $repository->getLatest(2);

        $this->assertCount(2, $brands);
        $this->assertInstanceOf(
            Brand::class,
            $brands[0]
        );
        $this->assertGreaterThan(
            $brands[1]->getId(),
            $brands[0]->getId()
        );
    }

    public function it_gets_names_indexed_by_id()
    {
        /** @var BrandRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Brand::class);

        $names = $repository->getNames();

        $this->assertCount(3, $names);
        $this->assertArrayHasKey(1, $names);
        $this->assertIsString($names[1]);
    }
}
