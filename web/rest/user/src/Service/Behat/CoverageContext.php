<?php

namespace Service\Behat;

use Behat\Behat\Context\Context;
use Behat\Behat\Hook\Scope\BeforeScenarioScope;
use SebastianBergmann\CodeCoverage\CodeCoverage;
use SebastianBergmann\CodeCoverage\Driver\Selector;
use SebastianBergmann\CodeCoverage\Filter;
use SebastianBergmann\CodeCoverage\Report\Html\Facade;
use SebastianBergmann\CodeCoverage\Report\PHP;

/**
 * Collects code coverage while the Behat API suite runs.
 *
 * The context is inert unless the COVERAGE environment variable is set, so it
 * can stay wired into the default profile without slowing regular test runs.
 * When enabled it requires a coverage driver (Xdebug/PCOV in coverage mode).
 */
class CoverageContext implements Context
{
    private static ?CodeCoverage $coverage = null;

    private static function enabled(): bool
    {
        return (bool) getenv('COVERAGE');
    }

    /**
     * @BeforeSuite
     */
    public static function setup(): void
    {
        if (!self::enabled()) {
            return;
        }

        $appRoot = dirname(__DIR__, 3);
        $repoRoot = dirname($appRoot, 3);

        $filter = new Filter();
        $filter->includeDirectory($repoRoot . '/library/Ivoz');
        $filter->includeDirectory($appRoot . '/src');

        self::$coverage = new CodeCoverage(
            (new Selector())->forLineCoverage($filter),
            $filter
        );
        self::$coverage->includeUncoveredFiles();
        self::$coverage->processUncoveredFiles();
    }

    /**
     * @AfterSuite
     */
    public static function tearDown(): void
    {
        if (!self::enabled() || self::$coverage === null) {
            return;
        }

        $outputDir = dirname(__DIR__, 3) . '/features/coverage';
        @mkdir($outputDir, 0777, true);
        (new Facade())->process(self::$coverage, $outputDir);
        (new PHP())->process(self::$coverage, $outputDir . '/coverage.php');
    }

    /**
     * @BeforeScenario
     */
    public function startCoverage(BeforeScenarioScope $scope): void
    {
        if (!self::enabled() || self::$coverage === null) {
            return;
        }

        $feature = $scope->getFeature()->getTitle();
        $title = $scope->getScenario()->getTitle();

        self::$coverage->start("{$feature}::{$title}");
    }

    /**
     * @AfterScenario
     */
    public function stopCoverage(): void
    {
        if (!self::enabled() || self::$coverage === null) {
            return;
        }

        self::$coverage->stop();
    }
}
